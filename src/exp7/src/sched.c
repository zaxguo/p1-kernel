#include "utils.h"
#include "sched.h"
#include "printf.h"

static struct task_struct init_task = INIT_TASK;
struct task_struct *current = &(init_task);
struct task_struct * task[NR_TASKS] = {&(init_task), };
int nr_tasks = 1;

struct cpu cpus[NCPU]; 

// this only prevents timer_tick() from calling schedule(). 
// they don't prevent voluntary switch; or irq context
void preempt_disable(void)
{
	current->preempt_count++;
}

void preempt_enable(void)
{
	current->preempt_count--;
}


void _schedule(void)
{
	/* Ensure no context happens in the following code region. 
		We still leave irq on, because irq handler may set a task to be TASK_RUNNABLE, which 
		will be picked up by the scheduler below */		
	preempt_disable(); 
	int next,c;
	struct task_struct * p;

	while (1) {
		c = -1; // the maximum counter of all tasks 
		next = 0;

		/* Iterates over all tasks and tries to find a task in 
		TASK_RUNNING state with the maximum counter. If such 
		a task is found, we immediately break from the while loop 
		and switch to this task. */

		push_off();  // our scheduler lock, as irq context may touch @tasks 
		for (int i = 0; i < NR_TASKS; i++){
			p = task[i];
			if (p && (p->state == TASK_RUNNING || p->state == TASK_RUNNABLE)
						&& p->counter > c) {
				c = p->counter;
				next = i;
			}
		}
		pop_off(); 
		if (c) {
			break;
		}

		/* If no such task is found, this is either because i) no 
		task is in TASK_RUNNING|RUNNABLE state or ii) all such tasks have 0 counters.
		in our current implemenation which misses TASK_WAIT, only condition ii) is possible. 
		Hence, we recharge counters. Bump counters for all tasks once. */
		
		for (int i = 0; i < NR_TASKS; i++) {
			p = task[i];
			if (p) {
				p->counter = (p->counter >> 1) + p->priority;
			}
		}
	}
	switch_to(task[next]);
	preempt_enable();
}

void schedule(void)
{
	current->counter = 0;
	_schedule();
}

void switch_to(struct task_struct * next) 
{
	struct task_struct * prev; 

	if (current == next) 
		return;

	prev = current;
	current = next;

	if (prev->state == TASK_RUNNING) // preempted 
		prev->state = TASK_RUNNABLE; 
	current->state = TASK_RUNNING;

	set_pgd(next->mm.pgd);

	/*	 
		below is where context switch happens. 

		after cpu_switch_to(), the @prev's cpu_context.pc points to the instruction right after  
		cpu_switch_to(). this is where the @prev task will resume in the future. 
		for example, shown as the arrow below: 

			cpu_switch_to(prev, next);
			80d50:       f9400fe1        ldr     x1, [sp, #24]
			80d54:       f94017e0        ldr     x0, [sp, #40]
			80d58:       9400083b        bl      82e44 <cpu_switch_to>
		==> 80d5c:       14000002        b       80d64 <switch_to+0x58>
	*/
	cpu_switch_to(prev, next);  /* will branch to @next->cpu_context.pc ...*/
}

void schedule_tail(void) {
	preempt_enable();
}

void timer_tick()
{
	// printf("%s counter %d preempt_count %d \n", __func__, current->counter, current->preempt_count);

	--current->counter;
	if (current->counter > 0 || current->preempt_count > 0) 
		return;
	current->counter=0;

	/* Note: we just came from an interrupt handler and CPU just automatically disabled all interrupts. 
		Now call scheduler with interrupts enabled */
	enable_irq();
	_schedule();
	/* disable irq until kernel_exit, in which eret will resort the interrupt flag from spsr, which sets it on. */
	disable_irq(); 
}

void exit_process() {
    preempt_disable();
    for (int i = 0; i < NR_TASKS; i++) {
        if (task[i] == current) {
            task[i]->state = TASK_ZOMBIE;
            break;
        }
    }
    /* no need to free stack page...*/
    preempt_enable();
    schedule();
}

// Atomically release lock and sleep on chan.
// Reacquires lock when awakened.
// xzl: called with @lk held
void sleep(void *chan, struct spinlock *lk) {
    struct task_struct *p = current;

    // Must acquire p->lock in order to
    // change p->state and then call sched.
    // Once we hold p->lock, we can be
    // guaranteed that we won't miss any wakeup
    // (wakeup locks p->lock),
    // so it's okay to release lk.

    //   acquire(&p->lock);  //DOC: sleeplock1
    push_off(); // xzl	this is our scheduler lock
    release(lk);

    // Go to sleep.
    p->chan = chan;
    p->state = TASK_SLEEPING;

    pop_off();

    _schedule();

    // Tidy up.
    p->chan = 0;

    // Reacquire original lock.
    //   release(&p->lock);
    acquire(lk);
}

// Wake up all processes sleeping on chan.
// Must be called without any p->lock.
// xzl: may be called from irq & tasks?
void wakeup(void *chan) {
    struct task_struct *p;

    // our scheduler lock. can't do disable_irq()/enable_irq() here b/c the func may be called with
    // another spinlock held (which already disabled irq), cf. releasesleep()
    // if so, the enable_irq below
    // would prematurely release that spinlock -- bad.
    push_off();

	for (int i = 0; i < NR_TASKS; i ++) {
		p = task[i]; 
        if (p != current) {
            //   acquire(&p->lock);
            if (p->state == TASK_SLEEPING && p->chan == chan) {
                p->state = TASK_RUNNABLE;
            }
            //   release(&p->lock);
        }
    }
    pop_off();
}

// Kill the process with the given pid.
// The victim won't exit until it tries to return
// to user space (see usertrap() in trap.c).
int kill(int pid) {
    int i;
    struct task_struct *p;

    push_off();

    for (i = 0; i < NR_TASKS; i++) {
        p = task[i];
        // acquire(&p->lock);
        if (i == pid) { // index is pid
            p->killed = 1;
            if (p->state == TASK_SLEEPING) {
                // Wake process from sleep().
                p->state = TASK_RUNNABLE;
            }
            //   release(&p->lock);
            pop_off();
            return 0;
        }
        // release(&p->lock);
    }
    pop_off();
    return -1;
}

void setkilled(struct task_struct *p) {
    // acquire(&p->lock);
	push_off(); 
    p->killed = 1;
    // release(&p->lock);
	pop_off(); 
}

int killed(struct task_struct *p) {
    int k;

    // acquire(&p->lock);
	push_off(); 
    k = p->killed;
    // release(&p->lock);
	pop_off(); 
    return k;
}

// Print a process listing to console.  For debugging.
// Runs when user types ^P on console.
// No lock to avoid wedging a stuck machine further.
void
procdump(void)
{
	printf("%s: TBD\n", __func__); 

	#if 0
  static char *states[] = {
  [UNUSED]    "unused",
  [USED]      "used",
  [SLEEPING]  "sleep ",
  [RUNNABLE]  "runble",
  [RUNNING]   "run   ",
  [ZOMBIE]    "zombie"
  };
  struct proc *p;
  char *state;

  printf("\n");
  for(p = proc; p < &proc[NPROC]; p++){
    if(p->state == UNUSED)
      continue;
    if(p->state >= 0 && p->state < NELEM(states) && states[p->state])
      state = states[p->state];
    else
      state = "???";
    printf("%d %s %s", p->pid, state, p->name);
    printf("\n");
  }
  #endif 
}