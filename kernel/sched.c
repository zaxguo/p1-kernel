#define K2_DEBUG_VERBOSE
// #define K2_DEBUG_INFO
// #define K2_DEBUG_WARN

#include "plat.h"
#include "utils.h"
#include "sched.h"
#include "printf.h"
#include "spinlock.h"
#include "mmu.h"
#include "entry.h"

//  locking protocol 
//  sched_lock is our 'scheduler lock'. protects adding/deleting/iterating of task[] entries.
//  task_struct::state indicates whehter a slot is free, sched_lock must be 
//  held to access it. 
// 
//  task::cpu_context is not protected with lock, as it is only touched in 
//  task creation and cpu_switch_to(), when no other code would access cpu_context
// 
//  all other fields in a task::struct is protected by task_struct::lock
//

static struct mm_struct mm_tables[NR_MMS];

// TODO: have a separate global lock (mtable_lock) for all mm::ref. hence, 
// allocating/freeing mm slots won't need to take individual mm->lock, which 
// might be slowed down by, e.g. a task is holding mm->lock during exec()


// kernel_stacks[i]: kernel stack for task with pid=i. 
// WARNING: various kernel code assumes each kernel stack is page-aligned. 
// cf. ret_from_syscall (entry.S). if you modify the d/s below, keep that in mind. 
static char kernel_stacks[NR_TASKS][THREAD_SIZE] __attribute__ ((aligned (THREAD_SIZE))); 

struct task_struct *init_task; 
struct task_struct *task[NR_TASKS];
struct spinlock sched_lock = {.locked=0, .cpu=0, .name="sched"};
int lastpid=0; // a hint for the next free tcb slot. slowdown pid reuse for dbg ease

struct cpu cpus[NCPU]; 

// helps ensure that wakeups of wait()ing
// parents are not lost. helps obey the
// memory model when using p->parent.
// must be acquired before any p->lock.
// xzl: parent task will hold this lock to wait for child to exit. (sleep() on its own task struct)
// protects p->parent relation. like the above said ^^ enforce happen-after mem order
// for p->parent. 
// XXX do we still need this? I guess we can make p->parent atomic with SEQ, then 
// just replace it w sched_lock
struct spinlock wait_lock = {.locked=0, .cpu=0, .name="wait_lock"};

// prevent timer_tick() from calling schedule(). 
// they don't prevent voluntary switch; or disable irq handler 
void preempt_enable(void) { myproc()->preempt_count--; }
void preempt_disable(void) { myproc()->preempt_count++; }

struct task_struct *myproc(void) {      // MP
    struct task_struct *p;
	push_off();
    p=mycpu()->proc; 
    pop_off(); 
	return p; 
};

/* get a task's saved registers ("trapframe"), at the top of the task's kernel page. 
   these regs are saved/restored by kernel_entry()/kernel_exit(). 
*/
struct pt_regs * task_pt_regs(struct task_struct *tsk) {
	unsigned long p = (unsigned long)tsk + THREAD_SIZE - sizeof(struct pt_regs);
	return (struct pt_regs *)p;
}


static void init(int arg/*ignored*/) {
	int wpid; 
    W("entering init");
	while (1) {
		wpid = wait(0 /* does not care about status */); 
		if (wpid < 0) {
			W("init: wait failed with %d", wpid);
			panic("init: maybe no child. has nothing to do. bye"); 
		} else {
			I("wait returns pid=%d", wpid);
			// a parentless task 
		}
	}
}

// must be called before any schedule() or timertick() occurs
void sched_init(void) {
    // acquire(&sched_lock);    
    for (int i = 0; i < NR_TASKS; i++) {
        task[i] = (struct task_struct *)(&kernel_stacks[i][0]); 
        BUG_ON((unsigned long)task[i] & ~PAGE_MASK);  // must be page aligned. see above
        memset(task[i], 0, sizeof(struct task_struct)); // zero everything
        initlock(&(task[i]->lock), "task");
        task[i]->state = TASK_UNUSED;
    }

    memset(mm_tables, 0, sizeof(mm_tables)); 
    for (int i = 0; i < NR_MMS; i++)
        initlock(&mm_tables[i].lock, "mmlock");
    
    // init task, will be picked up once the kernel call schedule()
    // current = init_task = task[0]; // UP
    // mycpu()->proc = init_task = task[0]; // MP
    mycpu()->proc = 0; // nothing, to be set by schedule()

    init_task->state = TASK_RUNNABLE;
    // acquire(&init_task->lock);
    // init_task->cpu_context = {0,0,0,0,0,0,0,0,0,0,0,0,0}; // already zeroed
    init_task->cpu_context.x19 = (unsigned long)init; 
    init_task->cpu_context.pc = (unsigned long)ret_from_fork; // entry.S
    init_task->cpu_context.sp = (unsigned long)init_task + THREAD_SIZE; 

    init_task->credits = 0;
    init_task->priority = 2;
    init_task->preempt_count = 0;
    init_task->flags = PF_KTHREAD;
    init_task->mm = 0;  // nothing 
    init_task->chan = 0;
    init_task->killed = 0;
    init_task->pid = 0;
    init_task->cwd = 0;
    // init_task->ofile // already zeroed
    safestrcpy(init_task->name, "init", 5);
    // release(&init_task->lock);
    // release(&sched_lock);
}

// return cpuid for the task is currently on; 
// -1 on no found or error
// caller must hold sched_lock
static int task_on_cpu(struct task_struct *p) {
    if (!p) {BUG(); return -1;}
    for (int i = 0; i < NCPU; i++)
        if (cpus[i].proc == p)
            return i; 
    return -1; 
}

// the scheduler, called by tasks or irq
// isirq=1: called from a irq context (e.g. timer/driver). if no task to run, return. 
//      returns to the interrupted task (e.g. which is in wfi inside schedule())
//      this avoids repeated calls to schedule(isirq=1) w/o return, which 
//      exhausts the kernel stack of the interrupted task
// isirq=0: called from a task context, if no task to run, wfi inside schedule()
//      subsequent local irq (after irq handler) will resume from wfi and 
//      retry the schedule loop
// caller must NOT hold sched_lock, or any p->lock
void schedule(int isirq) {
    V("cpu%d schedule", cpuid());
    
	/* Prevent timer irqs from calling schedule(), while we exec the following code region. 
        This may result in unnecessary nested schedule()
		We still leave irq on, because irq handler may set a task to be TASK_RUNNABLE, which 
		will be picked up by the schedule loop below */		
	preempt_disable(); 

	int next, c;
    int cpu = cpuid(), oncpu;
    
    // this cpu will hold on to "cur", i.e. using its kernel stack, 
    // until the cpu switch_to a diff task, changing the kernel stack. 
	struct task_struct *p, *cur=myproc();  XXXXXXXXX cur can be 0
    int has_runnable; 

    acquire(&sched_lock); 

	while (1) {
		c = -1; // the maximum counter of all tasks 
		next = 0;
        has_runnable = 0; 
        // cur = myproc(); 

		/* Iterates over all RUNNABLE tasks (+ the cur task, if it's RUNNING)
            and tries to find a task w/ maximum credits. If such a task is
		    found, break from the while loop and switch to it. */
		for (int i = 0; i < NR_TASKS; i++){
			p = task[i]; BUG_ON(!p);
            oncpu = task_on_cpu(p); 
            if (oncpu != -1 && oncpu != cpu) // task on other cpu, dont touch
                continue;
			if ((p == cur && p->state == TASK_RUNNING)
                || p->state == TASK_RUNNABLE) {
                has_runnable = 1; 
                acquire(&p->lock); 
				if (p->credits > c) { c = p->credits; next = i; }
                release(&p->lock); 
			}
		}
        // pick such a task as next
		if (c > 0)
			break;

		// No task can run 
        if (has_runnable) { 
            // tasks w/ insufficient credits, recharge for all & retry scheduling
            for (int i = 0; i < NR_TASKS; i++) {
                p = task[i]; BUG_ON(!p);
                if (p->state != TASK_UNUSED) {
                    acquire(&p->lock); 
                    p->credits = (p->credits >> 1) + p->priority;  // per priority
                    release(&p->lock); 
                }
            }
        } else { // no tasks in RUNNABLE (inc. cur task)
            I("cpu%d nothing to run", cpu);
#ifdef K2_DEBUG_VERBOSE
            for (int i = 0; i < NR_TASKS; i++) {
                p= task[i];
                if (p->state != TASK_UNUSED)
                    W("\t\t pid %d state %d chan %lx", p->pid, p->state, (unsigned long) p->chan);
            }
#endif
            if (isirq)
                goto leave;     // return from irq
            release(&sched_lock);   // let other cpus schedule()
            // this cpu sleep on the cur task's stack; other cpus won't steal
            // the cur task away 
            asm volatile("wfi");
            acquire(&sched_lock); 
        }
	}
    // W("cpu%d picked pid %d", cpu, next);
    I("cpu%d picked pid %d state %d", cpu, next, task[next]->state);
	switch_to(task[next]);
leave:     
    release(&sched_lock);
	preempt_enable();
    // leave the scheduler 
}

// Another path to leave the scheduler
// this function exists b/c when a task is first time switch_to()'d (see above), 
// its pc points to ret_from_fork instead of the instruction right after 
// switch_to(). to make the preempt_disable/enable balance, ret_from_fork calls
// schedule_tail() below
void schedule_tail(void) {
    release(&sched_lock);
	preempt_enable();
}

// voluntarily reschedule; gives up all remaining schedule credits
// only called from tasks
void yield(void) {    
    struct task_struct *p = myproc(); 
    acquire(&p->lock); p->credits = 0; release(&p->lock);
    schedule(0/*isirq*/);
}

// caller must hold sched_lock, and not holding next->lock
// called when preemption is disabled, so the cur task wont lose cpu
void switch_to(struct task_struct * next) {
	struct task_struct * prev; 
    struct task_struct *cur; 

    cur = myproc(); XXXXXXXXXXX deal with cur == 0
	if (cur == next) 
		return; 

	prev = cur;
	mycpu()->proc = next;

	if (prev && prev->state == TASK_RUNNING) // preempted 
		prev->state = TASK_RUNNABLE; 
	next->state = TASK_RUNNING;

    acquire(&next->lock); 
    if (next->mm) { // user task
        acquire(&next->mm->lock); 
	    set_pgd(next->mm->pgd);
        release(&next->mm->lock); 
        // now, next->mm should be effective. 
        // can use gdb to inspect user mapping here
    }
    release(&next->lock); 

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

        cpu_switch_to() does not need task::lock, cf "locking protocol" on the top
	*/
	cpu_switch_to(prev, next);  // sched.S will branch to @next->cpu_context.pc
}

// caller by timer irq handler, with irq automatically off by hardware
void timer_tick() {
    struct task_struct *cur = myproc();
    __attribute_maybe_unused__ int cpu = cpuid();
    // V("enter timer_tick");
    if (cur) {
        I(">>>>>>>>> enter timer_tick cpu%d pid %d", cpu, cur->pid);
        acquire(&cur->lock); 
        V("%s credits %ld preempt_count %ld", __func__, 
            cur->credits, cur->preempt_count);
        --cur->credits; 
        if (cur->credits > 0 || cur->preempt_count > 0) {
            // cur task continues to exec
            I("<<<<<<<<<< leave timer_tick. no resche");
            release(&cur->lock); return;
        }
        cur->credits=0;
        release(&cur->lock);
    }

	/* reschedule with irq on */
	enable_irq();
        /* what if a timer irq happens here? schedule() will be called 
            twice back-to-back, no interleaving so we're fine. */
	schedule(1/*isirq*/);

    I("<<<<<<<<<< leave timer_tick cpu%d pid %d", cpuid(), cur->pid);
	/* disable irq until kernel_exit, in which eret will resort the interrupt 
        flag from spsr, which sets it on. */
	disable_irq(); 
}

// Wake up all processes sleeping on chan. Only change p->state; wont schedule()
// Called from irq (many drivers) or task
// return # tasks woken up
// Must be called WITHOUT any p->lock, without sched_lock 
int wakeup(void *chan) {
    struct task_struct *p;
    int cnt = 0; 
    acquire(&sched_lock);     

    // V("chan=%lx", (unsigned long)chan);

	for (int i = 0; i < NR_TASKS; i ++) {
		p = task[i]; 
        // if (p && p != current) { // xv6
        // xzl: p ==current possible. e.g. current task can be the only task sleeping on 
        //      an io event. it shall wake up
        if (p->state == TASK_UNUSED) continue; 
        acquire(&p->lock);     // for p->chan. also cf sleep() below
        if (p->state == TASK_SLEEPING && p->chan == chan) {
            p->state = TASK_RUNNABLE;
            cnt ++; 
            I("wakeup cpu%d chan=%lx pid %d", cpuid(),
                (unsigned long)p->chan, p->pid);
        }
        release(&p->lock);
    }
    release(&sched_lock);
    return cnt; 
}

// Atomically release lock and sleep on chan.
// Reacquires lock when awakened.
// Called by tasks with @lk held
void sleep(void *chan, struct spinlock *lk) {
    struct task_struct *p = myproc();

    // Must acquire p->lock in order to
    // change p->state and then call sched.
    // Once we hold p->lock, we can be
    // guaranteed that we won't miss any wakeup
    // (wakeup locks p->lock),
    // so it's okay to release lk.

    acquire(&p->lock);  //DOC: sleeplock1
    release(lk);

    I("sleep chan=%lx pid %d", (unsigned long)chan, p->pid);

    // Go to sleep.
    p->chan = chan;
    p->state = TASK_SLEEPING;

    // xzl: sleep w/o p->lock, b/c other code (e.g. schedule())
    //  may inspect this task_struct.
    //  otherwise, it may sleep w/ p->lock held. 
    release(&p->lock);     
    schedule(0/*isirq*/);
    acquire(&p->lock); 

    // Tidy up.
    p->chan = 0;

    // Reacquire original lock.
    release(&p->lock);
    acquire(lk);
}

// Pass p's abandoned children to init. (ie direct reparent to initprocess)
// Caller must hold wait_lock.   
void reparent(struct task_struct *p) {
    struct task_struct **child;
    
    acquire(&sched_lock); 
    for (child = task; child < &task[NR_TASKS]; child++) {
        BUG_ON(!(*child));
        if ((*child)->state == TASK_UNUSED) continue;
        // acquire(&(*child)->lock);  // only wait_lock needed
        if ((*child)->parent == p) {
            (*child)->parent = init_task;
            // release(&(*child)->lock); 
            release(&sched_lock);   // XXX refactor this 
            wakeup(init_task); // must call w/o any p->lock, sched_lock
            acquire(&sched_lock); 
        } else 
            ; // release(&(*child)->lock); 
    }
    release(&sched_lock); 
}

// becomes a zombie task and schedule() a different task 
// the actual destruction happens when parent calls wait() this zombie 
// task successfully. only at that time the zombie's kernel stack (and task_struct
// on it) will be recycled.
void exit_process(int status) {
    struct task_struct *p = myproc();

    I("pid %d (%s): exit_process status %d", p->pid, p->name, status);

    if (p == init_task)
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

    // xzl: take lock b/c the parent may check this task_struct. cf wait() code below
    acquire(&p->lock); 
    p->xstate = status;
    p->state = TASK_ZOMBIE;
    release(&p->lock); // xzl: dont hold the lock to scheduler(), unlike xv6...

    release(&wait_lock);

    // Jump into the scheduler, never to return.
    V("exit done. will call schedule...");
    yield();
    panic("zombie exit");
}

// xzl: destroys a task: task_struct, kernel stack, etc. 
// free a proc structure and the data hanging from it,
// including user & kernel pages. 
//
// sched_lock must be held.  p->lock must be held
static void freeproc(struct task_struct *p) {
    BUG_ON(!p || !p->mm); V("%s entered. pid %d", __func__, p->pid);

    p->state = TASK_UNUSED; // mark the slot as unused
    // no need to zero task_struct, which is among the task's kernel page
    // FIX: since we cannot recycle task slot now, so we dont dec nr_tasks ...

    acquire(&p->mm->lock);
    p->mm->ref --; BUG_ON(p->mm->ref<0);
    if (p->mm->ref == 0) { // this marks p->mm as unused
        V("<<<< free mm %lu", p->mm-mm_tables); 
        free_task_pages(p->mm, 0 /* free all user and kernel pages*/);        
    } 
    release(&p->mm->lock); 
    
    p->mm = 0; 
    p->flags = 0; 
    p->killed = 0; 
    p->credits = 0; 
    p->preempt_count = 0; 
    p->chan = 0; 
    p->pid = 0; 
    p->xstate = 0; 
}

// Wait for a child process to exit and return its pid.
// Return -1 if this process has no children. 
// addr=0 a special case, dont care about status
int wait(uint64 addr /*dst user va to copy status to*/) {
    struct task_struct **pp;
    int havekids, pid;
    struct task_struct *p = myproc();

    I("pid %d (%s) entering wait()", p->pid, p->name);

    acquire(&wait_lock);
    
    for (;;) {
        acquire(&sched_lock); 
        // Scan through table looking for exited children.  pp:child
        havekids = 0;
        for (pp = task; pp < &task[NR_TASKS]; pp++) {
            struct task_struct *p0 = *pp; BUG_ON(!p0); 
            if (p0->state == TASK_UNUSED) continue; 
            // make sure the child isn't still in exit() or swtch().
            // cf exit_process() above 
            acquire(&p0->lock);
            if (p0->parent == p) {
                havekids = 1;
                if (p0->state == TASK_ZOMBIE) {
                    // Found one.
                    pid = p0->pid;
                    I("found zombie pid=%d", pid); BUG_ON(addr!=0 && !p->mm);//addr!=0 implies user task; mm must exist
                    if (addr != 0 && copyout(p->mm, addr, (char *)&(p0->xstate),
                                             sizeof(p0->xstate)) < 0) {
                        release(&p0->lock);
                        release(&sched_lock); 
                        release(&wait_lock);
                        return -1;
                    }
                    // task[pid] = 0;   // no longer need this. as we have sched_lock
                    freeproc(p0);       // will mark the task slot as unused
                    // below is safe, b/c freeproc() only marks p0 as UNUSED; the task slot 
                    // wont be reused until we release sched_lock below
                    release(&p0->lock); 
                    release(&sched_lock); 
                    release(&wait_lock);
                    return pid;
                }
            }
            release(&p0->lock);
        }
        release(&sched_lock); 

        // No point waiting if we don't have any children.
        if (!havekids || killed(p)) {
            release(&wait_lock);
            return -1;
        }

        // Wait for a child to exit.
        I("pid %d sleep on %lx", p->pid, (unsigned long)&wait_lock);
        sleep(p, &wait_lock); // DOC: wait-sleep
        I("pid %d wake up from sleep. p->chan %lx state %d", p->pid, 
            (unsigned long)p->chan, p->state);
    }
}

// Kill the process with the given pid.
// The victim won't exit until it tries to return
// to user space (see ret_from_syscall).
int kill(int pid) {
    int i;
    struct task_struct *p;

    // push_off();
    acquire(&sched_lock); 

    for (i = 0; i < NR_TASKS; i++) {
        p = task[i];
        BUG_ON(!p); BUG_ON(i==pid && p->state == TASK_UNUSED);
        if (p->state == TASK_UNUSED) continue;
        if (i == pid) { // index is pid
            acquire(&p->lock); p->killed = 1; release(&p->lock);
            if (p->state == TASK_SLEEPING) {
                // Wake process from sleep().
                p->state = TASK_RUNNABLE;
            }            
            release(&sched_lock); 
            // pop_off();
            I("kill succeeds, pid =%d", pid);
            return 0;
        }
    }
    // pop_off();
    release(&sched_lock); 
    W("kill failed, pid =%d", pid);
    return -1;
}

// mark a task as "killed" (e.g. a faulty one)
// causes exit_process() to be called in ret_from_syscall (entry.S)
void setkilled(struct task_struct *p) {
    acquire(&p->lock);
	// push_off(); 
    p->killed = 1;
    release(&p->lock);
	// pop_off(); 
}

int killed(struct task_struct *p) {
    int k;
    acquire(&p->lock);
	// push_off(); 
    k = p->killed;
    release(&p->lock);
	// pop_off(); 
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

////// fork.c 

// alloc a blank mm. on success, return mm, AND hold mm->lock 
// on failure, return 0
static struct mm_struct *alloc_mm(void) {
    struct mm_struct *mm; 
    for (mm = mm_tables; mm < mm_tables + NR_MMS; mm++) {
        acquire(&mm->lock);
        if (mm->ref == 0)
            break; 
        else 
            release(&mm->lock);
    }
    if (mm == mm_tables + NR_MMS) 
        {E("no free mm"); BUG(); return 0;}  
    // now we hold mm->lock
    mm->ref = 1; 
    mm->pgd = 0; 
    mm->kernel_pages_count = 0;
    mm->user_pages_count = 0;
    V(">>>> alloc_mm %lu", mm-mm_tables); 
    return mm;
}

/*
   	Create 1st user task by elevating a kernel task to EL1

	Populate pt_regs for returning to user space (via kernel_exit) for the 1st time.
	Note that the actual switch will not happen until kernel_exit.

	@start: beginning of the user code (to be copied to the new task). kernel va
	@size: size of the initial code area
	@pc: offset of the startup function inside the area

    return 0 on ok, -1 on failure
*/

int move_to_user_mode(unsigned long start, unsigned long size, unsigned long pc)
{
    BUG_ON(size > PAGE_SIZE); // initially, user va only covers [0,PAGE_SIZE)
    struct task_struct *cur = myproc();

	struct pt_regs *regs = task_pt_regs(cur);
	V("pc %lx", pc);

    BUG_ON(cur->mm); // kernel task has no mm 

    if (!(cur->mm = alloc_mm())) return -1; 
    // now we have current->mm->lock

	regs->pstate = PSR_MODE_EL0t;
	regs->pc = pc;
	regs->sp = USER_VA_END; // 2 *  PAGE_SIZE;  <--too small

	/* only allocate 1 code page here b/c the stack page is to be mapped on demand. 
	   this will trigger allocating the task's pgtable tree (mm.pgd)
	*/	
	void *code_page = allocate_user_page_mm(cur->mm, 0 /*va*/, 
        MMU_PTE_FLAGS | MM_AP_RW);
	if (code_page == 0)	{
        release(&cur->mm->lock);
		return -1;
	}	
    // at this time, user vm only covers [0,PAGE_SIZE). large enough for the init user
    // code, which later invokes exec() and enlarges mm->sz
	cur->mm->sz = cur->mm->codesz = PAGE_SIZE; 
	memmove(code_page, (void *)start, size); 	
	set_pgd(cur->mm->pgd);

	safestrcpy(cur->name, "initusr", sizeof(cur->name));
	cur->cwd = namei("/");
	BUG_ON(!cur->cwd); 
    release(&cur->mm->lock);

    // (from xv6) File system initialization must be run in the context of a
    // regular process (e.g., because it calls sleep), and thus cannot
    // be run from main().
    fsinit(ROOTDEV);
	fsinit(SECONDDEV); // fat
	
	return 0;
}

// for creating both user and kernel tasks
// return pid on success, <0 on err
// clone_flags: PF_KTHREAD for kernel thread, PF_UTHREAD for user thread
// fn: only matters for PF_KTHREAD. task func entry 
// arg: arg to kernel thread; or stack (userva) for user thread
int copy_process(unsigned long clone_flags, unsigned long fn, unsigned long arg)
{
	struct task_struct *p = 0, *cur=myproc(); 
    int i, pid; 
	acquire(&sched_lock);
	
	// find an empty tcb slot
	for (i = 0; i < NR_TASKS; i++) {
        pid = (lastpid+1+i) % NR_TASKS; 
		p = task[pid]; BUG_ON(!p); 
		if (p->state == TASK_UNUSED)
			{V("alloc pid %d", pid); lastpid=pid; break;}
	}	
	if (i == NR_TASKS) 
		{release(&sched_lock); return -1;}

	memset(p, 0, sizeof(struct task_struct));
	initlock(&p->lock, "proc");

	acquire(&p->lock);	
    acquire(&cur->lock);	

	struct pt_regs *childregs = task_pt_regs(p);

	if (clone_flags & PF_KTHREAD) { /* create a kernel task */
		p->cpu_context.x19 = fn;
		p->cpu_context.x20 = arg;
    } else { /* fork user tasks */
        struct pt_regs *cur_regs = task_pt_regs(cur);
        *childregs = *cur_regs; // copy over the entire pt_regs
        childregs->regs[0] = 0; // return value (x0) for child
        if (clone_flags & PF_UTHREAD) {	// fork a "thread", i.e. sharing an existing mm
            p->mm = cur->mm; BUG_ON(!p->mm);
            acquire(&p->mm->lock);
            p->mm->ref++;
            release(&p->mm->lock);
            childregs->sp = arg; V("childregs->sp %lx", childregs->sp);
        } else {	// for a "process", alloc a new mm of its own
            struct mm_struct *mm = alloc_mm();
            if (!mm) {BUG(); return -1;}  // XXX reverse task allocation
			// now we hold mm->lock
            p->mm = mm; V("new mm %lx", (unsigned long)mm); 
            dup_current_virt_memory(mm); // duplicate virt memory (inc contents)
            release(&mm->lock);
        }
        // that's it, no modifying pc/sp/etc

		// user task only: dup fds (kernel tasks won't need them)
		// 		increment reference counts on open file descriptors.
		for (int i = 0; i < NOFILE; i++)
			if (cur->ofile[i])
				p->ofile[i] = filedup(cur->ofile[i]);
		p->cwd = idup(cur->cwd);		
    }

    // also inherit task name
	safestrcpy(p->name, cur->name, sizeof(cur->name));		

	p->flags = clone_flags;
	p->credits = p->priority = cur->priority;
	p->preempt_count = 1; //disable preemption until schedule_tail
	
	// TODO: init more field here
	// @page is 0-filled, many fields (e.g. mm.pgd) are implicitly init'd

	p->cpu_context.pc = (unsigned long)ret_from_fork; // entry.S
	p->cpu_context.sp = (unsigned long)childregs; // XXX in fact PF_KTHREAD can use all the way to the top of the stack page...
	p->pid = pid; 
    release(&cur->lock);
	release(&p->lock);

  	acquire(&wait_lock);
 	p->parent = cur;
  	release(&wait_lock);

	// the last thing ... hence scheduler can pick up
	p->state = TASK_RUNNABLE;

	release(&sched_lock);

	return pid;
}
