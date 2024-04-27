#define K2_DEBUG_WARN
// #define K2_DEBUG_INFO
// #define K2_DEBUG_VERBOSE

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

struct task_struct *init_task, *current; 
struct task_struct *task[NR_TASKS];
struct spinlock sched_lock = {.locked=0, .cpu=0, .name="sched"};

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
// XXXX need a btter design. like per-cpu? also does preempt_count need lock??
void preempt_disable(void) { current->preempt_count++; }
void preempt_enable(void) { current->preempt_count--; }

/* get a task's saved registers ("trapframe"), at the top of the task's kernel page. 
   these regs are saved/restored by kernel_entry()/kernel_exit(). 
*/
struct pt_regs * task_pt_regs(struct task_struct *tsk) {
	unsigned long p = (unsigned long)tsk + THREAD_SIZE - sizeof(struct pt_regs);
	return (struct pt_regs *)p;
}

// must be called before any schedule() or timertick() occurs
void sched_init(void) {
    acquire(&sched_lock);    
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
    
    current = init_task = task[0]; // XXX has to change for multicore
    
    init_task->state = TASK_RUNNABLE;

    acquire(&init_task->lock);
    // init_task->cpu_context = {0,0,0,0,0,0,0,0,0,0,0,0,0}; // already zeroed
    init_task->counter = 0;
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
    release(&init_task->lock);
    release(&sched_lock);
}

// the scheduler 
void _schedule(void) {
    V("_schedule");
    
	/* Prevent timer irqs from calling schedule(), while we exec the following code region. 
        This may result in unnecessary nested schedule()
		We still leave irq on, because irq handler may set a task to be TASK_RUNNABLE, which 
		will be picked up by the schedule loop below */		
	preempt_disable(); 

	int next, c;
	struct task_struct * p;
    int has_runnable; 

    acquire(&sched_lock); 

	while (1) {
		c = -1; // the maximum counter of all tasks 
		next = 0;
        has_runnable = 0; 

		/* Iterates over all tasks and tries to find a task in 
		TASK_RUNNING state with the maximum counter. If such 
		a task is found, we immediately break from the while loop 
		and switch to this task. */
		for (int i = 0; i < NR_TASKS; i++){
			p = task[i]; BUG_ON(!p);
			if (p->state == TASK_RUNNING || p->state == TASK_RUNNABLE) {
                has_runnable = 1; 
                acquire(&p->lock); 
				if (p->counter > c) {
				    c = p->counter;
				    next = i;
                }
                release(&p->lock); 
			}
		}		
        // pick such a task as next
		if (c > 0)
			break;

		/* If no such task is found, this is either because i) no 
		task is in TASK_RUNNING|RUNNABLE or ii) all such tasks have 0 counters.*/
		
        if (has_runnable) { // recharge counters for all tasks once, per priority */		
            for (int i = 0; i < NR_TASKS; i++) {
                p = task[i]; BUG_ON(!p);
                if (p->state != TASK_UNUSED) {
                    acquire(&p->lock); 
                    p->counter = (p->counter >> 1) + p->priority;
                    release(&p->lock); 
                }
            }
        } else { /* nothing to run. */
            V("nothing to run");             
#ifdef K2_DEBUG_VERBOSE            
            for (int i = 0; i < NR_TASKS; i++) {
                p= task[i];
                if (p->state != TASK_UNUSED)
                    W("pid %d state %d chan %lx", p->pid, p->state, (unsigned long) p->chan);
            }
#endif            
            release(&sched_lock);   // let other cores (if any) schedule()
            asm volatile("wfi");
            acquire(&sched_lock); 
        }
	}
    V("picked pid %d state %d", next, task[next]->state);
	switch_to(task[next]);
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

// called from tasks
void schedule(void) {
    acquire(&current->lock); current->counter = 0; release(&current->lock);
    _schedule();
}

// caller must hold sched_lock, and not holding next->lock
void switch_to(struct task_struct * next) {
	struct task_struct * prev; 

	if (current == next) 
		return;

	prev = current;
	current = next;

	if (prev->state == TASK_RUNNING) // preempted 
		prev->state = TASK_RUNNABLE; 
	current->state = TASK_RUNNING;

    acquire(&next->lock); 
    if (next->mm) { // user task
        acquire(&next->mm->lock); 
	    set_pgd(next->mm->pgd);
        release(&next->mm->lock); 
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

// caller by timer irq handler
void timer_tick() {
    V("timer_tick");
    acquire(&current->lock); 
	V("%s counter %ld preempt_count %ld", __func__, 
        current->counter, current->preempt_count);
	--current->counter;
	if (current->counter > 0 || current->preempt_count > 0) 
		{release(&current->lock); return;}
	current->counter=0;
    release(&current->lock);

	/* We just came from an interrupt handler and CPU just automatically disabled all interrupts. 
		Now call scheduler with interrupts enabled */
	enable_irq();
        /* what if a timer irq happens here? _schedule() will be called 
            twice back-to-back, no interleaving so we're fine. */
	_schedule();
	/* disable irq until kernel_exit, in which eret will resort the interrupt 
        flag from spsr, which sets it on. */
	disable_irq(); 
}

// Wake up all processes sleeping on chan.
// Called from irq (many drivers) or task
//
// Must be called WITHOUT any p->lock, without sched_lock 
void wakeup(void *chan) {
    struct task_struct *p;

    acquire(&sched_lock);     

    V("chan=%lx", (unsigned long)chan);

	for (int i = 0; i < NR_TASKS; i ++) {
		p = task[i]; 
        // if (p && p != current) { // xv6
        // xzl: p ==current possible. e.g. current task can be the only task sleeping on 
        //      an io event. it shall wake up
        if (p->state == TASK_UNUSED) continue; 
        acquire(&p->lock);     // for p->chan. also cf sleep() below
        if (p->state == TASK_SLEEPING && p->chan == chan) {
            p->state = TASK_RUNNABLE;
            I("wakeup chan=%lx pid %d", (unsigned long)p->chan, p->pid);
        }
        release(&p->lock);
    }
    release(&sched_lock);
}

// Atomically release lock and sleep on chan.
// Reacquires lock when awakened.
// Called by tasks with @lk held
void sleep(void *chan, struct spinlock *lk) {
    struct task_struct *p = current;

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

    // xzl: sleep w/o p->lock, b/c other code (e.g. _schedule())
    //  may inspect this task_struct.
    //  otherwise, it may sleep w/ p->lock held. 
    release(&p->lock);     
    _schedule();
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

// xzl: this only makes a task zombie, the actual destruction happens
// when parent calls wait() successfully
void exit_process(int status) {
    struct task_struct *p = myproc();

    V("pid %d (%s): exit_process status %d", current->pid, current->name, status);

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
    schedule();
    panic("zombie exit");
}

// xzl: destroys a task: task_struct, kernel stack, etc. 
// free a proc structure and the data hanging from it,
// including user & kernel pages. 
// sched_lock must be held.
static void freeproc(struct task_struct *p) {
    BUG_ON(!p || !p->mm); I("%s entered. target pid %d", __func__, p->pid);

    p->state = TASK_UNUSED; // mark the slot as unused
    // no need to zero task_struct, which is among the task's kernel page
    // FIX: since we cannot recycle task slot now, so we dont dec nr_tasks ...

    acquire(&p->mm->lock);
    p->mm->ref --; BUG_ON(p->mm->ref<0);
    if (p->mm->ref == 0) { // this marks p->mm as unused
        free_task_pages(p->mm, 0 /* free all user and kernel pages*/);        
    } 
    release(&p->mm->lock); 
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
                    V("found zombie pid=%d", pid); BUG_ON(addr!=0 && !p->mm);//addr!=0 implies user task; mm must exist
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
        I("pid %d sleep on %lx", current->pid, (unsigned long)&wait_lock);
        sleep(p, &wait_lock); // DOC: wait-sleep
        I("pid %d wake up from sleep. p->chan %lx state %d", current->pid, 
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

// used to mark a task as "killed" (e.g. a faulty one)
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
    if (mm == mm_tables + NR_MMS) {E("no free mm"); BUG(); return 0;}  
    // now we hold mm->lock
    mm->ref = 1; 
    mm->kernel_pages_count = 0;
    return mm;
}

// for creating both user and kernel tasks
// return pid on success, <0 on err
int copy_process(unsigned long clone_flags, unsigned long fn, unsigned long arg)
{
	struct task_struct *p = 0; int pid; 
	// push_off();	// stil need this for entire task array. may remove later
	acquire(&sched_lock);
	
	// find an empty tcb slot
	for (pid = 0; pid < NR_TASKS; pid++) {
		p = task[pid]; BUG_ON(!p); 
		if (p->state == TASK_UNUSED)
			break; 
	}	
	if (pid >= NR_TASKS) 
		return -1; 

	// task[pid] = p;	// take the spot. scheduler cannot kick in
	memset(p, 0, sizeof(struct task_struct));
	initlock(&p->lock, "proc");
	// pop_off();

	acquire(&p->lock);	
    acquire(&current->lock);	

	// (UPDATE) no longer doing so, as we free mm and task_struct separately
	// in order to support threading	
	// bookkeep the 1st kernel page (kern stack)
	// p->mm.kernel_pages[0] = VA2PA(p); 	
	// p->mm.kernel_pages_count = 0; 
	struct pt_regs *childregs = task_pt_regs(p);

	if (clone_flags & PF_KTHREAD) { /* create a kernel task */
		p->cpu_context.x19 = fn;
		p->cpu_context.x20 = arg;
    } else { /* fork user tasks */
        struct pt_regs *cur_regs = task_pt_regs(current);
        *childregs = *cur_regs; // copy over the entire pt_regs
        childregs->regs[0] = 0; // return value (x0) for child
        if (clone_flags & PF_UTHREAD) {	// fork a "thread", i.e. sharing an existing mm
            p->mm = current->mm; BUG_ON(!p->mm);
            acquire(&p->mm->lock);
            p->mm->ref++;
            release(&p->mm->lock);
        } else {	// for a "process", alloc a new mm of its own
            struct mm_struct *mm = alloc_mm();
            if (!mm) {BUG(); return -1;}  // XXX reverse task allocation
			// now we hold mm->lock
            p->mm = mm; 			
            dup_current_virt_memory(mm); // duplicate virt memory (inc contents)
            release(&mm->lock);
        }
        // that's it, no modifying pc/sp/etc

		// user task only: dup fds (kernel tasks won't need them)
		// 		increment reference counts on open file descriptors.
		for (int i = 0; i < NOFILE; i++)
			if (current->ofile[i])
				p->ofile[i] = filedup(current->ofile[i]);
		p->cwd = idup(current->cwd);		
    }

    // also inherit task name
	safestrcpy(p->name, current->name, sizeof(current->name));		

	p->flags = clone_flags;
	p->counter = p->priority = current->priority;
	p->preempt_count = 1; //disable preemption until schedule_tail
	
	// TODO: init more field here
	// @page is 0-filled, many fields (e.g. mm.pgd) are implicitly init'd

	p->cpu_context.pc = (unsigned long)ret_from_fork;
	p->cpu_context.sp = (unsigned long)childregs;	
	p->pid = pid; 
    release(&current->lock);
	release(&p->lock);

  	acquire(&wait_lock);
 	p->parent = current;
  	release(&wait_lock);

	// the last thing ... hence scheduler can pick up
	p->state = TASK_RUNNABLE;

	release(&sched_lock);

	return pid;
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

    // acquire(&current->lock); 
	struct pt_regs *regs = task_pt_regs(current);
	V("pc %lx", pc);

    BUG_ON(current->mm); // kernel task has no mm 

    if (!(current->mm = alloc_mm())) return -1; 
    // now we have current->mm->lock

	regs->pstate = PSR_MODE_EL0t;
	regs->pc = pc;
	regs->sp = USER_VA_END; // 2 *  PAGE_SIZE;  <--too small

	/* only allocate 1 code page here b/c the stack page is to be mapped on demand. 
	   this will trigger allocating the task's pgtable tree (mm.pgd)
	*/	
	void *code_page = allocate_user_page_mm(current->mm, 0 /*va*/, 
        MMU_PTE_FLAGS | MM_AP_RW);
	if (code_page == 0)	{
        release(&current->mm->lock); // release(&current->lock); 
		return -1;
	}	
    // at this time, user vm only covers [0,PAGE_SIZE). large enough for the init user
    // code, which later invokes exec() and enlarges mm->sz
	current->mm->sz = current->mm->codesz = PAGE_SIZE; 
	memmove(code_page, (void *)start, size); 	
	set_pgd(current->mm->pgd);

	safestrcpy(current->name, "user1st", sizeof(current->name));
	current->cwd = namei("/");
	BUG_ON(!current->cwd); 
    release(&current->mm->lock); //release(&current->lock); 

    // (from xv6) File system initialization must be run in the context of a
    // regular process (e.g., because it calls sleep), and thus cannot
    // be run from main().
    fsinit(ROOTDEV);
	fsinit(SECONDDEV); // fat
	
	return 0;
}
