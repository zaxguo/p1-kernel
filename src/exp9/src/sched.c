#define K2_DEBUG_WARN

#include "utils.h"
#include "sched.h"
#include "printf.h"
#include "spinlock.h"

// the initial values for task_struct that belongs to the init task. see sched.c 
// NB: init task is in kernel, only has kernel mapping (ttbr1) 
// 		no user mapping (ttbr0, mm->pgd=0)
static struct task_struct init_task = {
    .cpu_context = {0,0,0,0,0,0,0,0,0,0,0,0,0}, 
    .state = TASK_RUNNABLE, 					
    .counter = 0, 
    .priority = 2, 
    .preempt_count = 0, 
    .flags = PF_KTHREAD, 
    .mm = { 
        .pgd = 0, 
        .sz = 0, 
        .codesz = 0, 
        .user_pages_count = 0, 
        .kernel_pages_count = 0, 
        .kernel_pages = {0}
        }, 
    .chan = 0, 
    .killed = 0,
    .pid = 0, 
    .ofile = {0}, 
    .cwd = 0, 
    .name = "init"
};

struct task_struct *current = &(init_task);
struct task_struct * task[NR_TASKS] = {&(init_task), };
int nr_tasks = 1;

struct cpu cpus[NCPU]; 

// helps ensure that wakeups of wait()ing
// parents are not lost. helps obey the
// memory model when using p->parent.
// must be acquired before any p->lock.
struct spinlock wait_lock = {.locked=0, .cpu=0, .name="wait_lock"};

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
    int has_runnable; 

	while (1) {
		c = -1; // the maximum counter of all tasks 
		next = 0;
        has_runnable = 0; 

        push_off();  // our scheduler lock, as irq context may touch @tasks 

		/* Iterates over all tasks and tries to find a task in 
		TASK_RUNNING state with the maximum counter. If such 
		a task is found, we immediately break from the while loop 
		and switch to this task. */
		for (int i = 0; i < NR_TASKS; i++){
			p = task[i];
			if (p && (p->state == TASK_RUNNING || p->state == TASK_RUNNABLE)) {
                has_runnable = 1; 
				if (p->counter > c) {
				    c = p->counter;
				    next = i;
                }
			}
		}
		pop_off(); 
        // pick such a task as next
		if (c > 0) { 
			break;
		}

		/* If no such task is found, this is either because i) no 
		task is in TASK_RUNNING|RUNNABLE or ii) all such tasks have 0 counters.*/
		
        if (has_runnable) { // recharge counters for all tasks once, per priority */		
            for (int i = 0; i < NR_TASKS; i++) {
                p = task[i];
                if (p) {
                    p->counter = (p->counter >> 1) + p->priority;
                }
            }
        } else { /* nothing to run */
            // W("nothing to run"); 
            // for (int i = 0; i < NR_TASKS; i++) {
            //         p= task[i];
            //     if (p)
            //         W("pid %d state %d chan %lx", p->pid, p->state, (unsigned long) p->chan);
            // }
            asm volatile("wfi");
        }
	}
    V("picked pid %d state %d", next, task[next]->state);
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

    // W("chan=%lx", (unsigned long)chan);

	for (int i = 0; i < NR_TASKS; i ++) {
		p = task[i]; 
        // xzl: why p!=current? e.g. current task can be the only task sleeping on 
        //      an io event. it shall wake up
        // if (p && p != current) { 
        if (p) { 
            //   acquire(&p->lock);
            if (p->state == TASK_SLEEPING && p->chan == chan) {
                p->state = TASK_RUNNABLE;
                V("wakeup chan=%lx pid %d", (unsigned long)p->chan, p->pid);
            }
            //   release(&p->lock);
        }
    }
    pop_off();
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

// Pass p's abandoned children to init.
// Caller must hold wait_lock.   xzl: direct reparent to initprocess..
void reparent(struct task_struct *p) {
    struct task_struct **child;
    // we scan all tasks to be compatible with future "pid recycling" design
    for (child = task; child < &task[NR_TASKS]; child++) {
        if ((*child)->parent == p) {
            (*child)->parent = &init_task;
            wakeup(&init_task);
        }
    }
}

// xzl: this only makes a task zombie, the actual destruction happens
// when parent calls wait() successfully
void exit_process(int status) {
    struct task_struct *p = myproc();

    if (p == &init_task)
        panic("init exiting");

    // Close all open files.
    for (int fd = 0; fd < NOFILE; fd++) {
        if (p->ofile[fd]) {
            struct file *f = p->ofile[fd];
            fileclose(f);
            p->ofile[fd] = 0;
        }
    }

    begin_op();
    iput(p->cwd);
    end_op();
    p->cwd = 0;

    acquire(&wait_lock);

    // Give any children to init.
    reparent(p);

    // Parent might be sleeping in wait().
    wakeup(p->parent);

    acquire(&p->lock); // xzl: cf wait() code below

    p->xstate = status;
    p->state = TASK_ZOMBIE;

    release(&p->lock); // xzl: dont hold the lock to scheduler(), unlike xv6...

    release(&wait_lock);

    // Jump into the scheduler, never to return.
    V("exit done. will call schedule...");
    schedule();
    panic("zombie exit");

#if 0     
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
#endif
}

// xzl: destorys a task: task_struct, kernel stack, etc. 
// free a proc structure and the data hanging from it,
// including user pages. (and kernel pages)
// p->lock must be held.
static void
freeproc(struct task_struct *p) {
    BUG_ON(!p);
    V("%s entered. target pid %d", __func__, p->pid);
    free_task_pages(&p->mm, 0 /* free all user and kernel pages*/);
    // no need to zero task_struct, which is on the task's kernel page
    // FIX: since we cannot recycle task slot now, so we dont dec nr_tasks ...
}

// Wait for a child process to exit and return its pid.
// Return -1 if this process has no children. 
// addr=0 a special case, dont care about status
int wait(uint64 addr /*dst user va to copy status to*/) {
    struct task_struct **pp;
    int havekids, pid;
    struct task_struct *p = myproc();

    V("entering wait()");

    acquire(&wait_lock);

    for (;;) {
        // Scan through table looking for exited children. xzl pp:child
        havekids = 0;
        for (pp = task; pp < &task[NR_TASKS]; pp++) {
            struct task_struct *p0 = *pp; 
            if (!p0) 
                continue; 
            if (p0->parent == p) {
                // make sure the child isn't still in exit() or swtch().
                acquire(&p0->lock);

                havekids = 1;
                if (p0->state == TASK_ZOMBIE) {
                    // Found one.
                    pid = p0->pid;
                    V("found zombie pid=%d", pid);
                    if (addr != 0 && copyout(&p->mm, addr, (char *)&(p0->xstate),
                                             sizeof(p0->xstate)) < 0) {
                        release(&p0->lock);
                        release(&wait_lock);
                        return -1;
                    }
                    // xzl: detach pp from scheduler... sufficient to prevent race on pp?
                    //    another design is to disable irq here... 
                    task[pid] = 0;  
                    release(&p0->lock); 
                    freeproc(p0); // xzl: do it after release b/c it will destory the lock
                    release(&wait_lock);
                    return pid;
                }
                release(&p0->lock);
            }
        }

        // No point waiting if we don't have any children.
        if (!havekids || killed(p)) {
            release(&wait_lock);
            return -1;
        }

        // Wait for a child to exit.
        V("pid %d sleep on %lx", current->pid, (unsigned long)&wait_lock);
        sleep(p, &wait_lock); // DOC: wait-sleep
        V("pid %d wake up from sleep. p->chan %lx state %d", current->pid, 
            (unsigned long)p->chan, p->state);
    }
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
            assert(p); 
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