#include "plat.h"
#include "utils.h"
#include "sched.h"
#include "mmu.h"
#include "entry.h"

// one major limitation: need to recycle pids.

extern struct spinlock wait_lock;  // sched.c

// for creating both user and kernel tasks
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
        acquire(&current->lock);
        struct pt_regs *cur_regs = task_pt_regs(current);
        *childregs = *cur_regs; // copy over the entire pt_regs
        childregs->regs[0] = 0; // return value (x0) for child
        if (clone_flags & PF_UTHREAD) {	// user "thread", sharing an existing mm
            p->mm = current->mm;
            acquire(&p->mm->lock);
            p->mm->ref++;
            release(&p->mm->lock);
        } else {	// user "process", need a new mm of its own
            struct mm_struct *mm; 
            for (mm = mm_tables; mm < mm_tables + NR_MMS; mm++) {
                acquire(&mm->lock);
                if (mm->ref == 0)
                	break; 
				else 
					release(&mm->lock);
            }
            if (mm == mm_tables + NR_MMS) {E("no free mm"); BUG(); return -1;}  // XXX reverse task allocation
			// now we hold mm->lock
			mm->kernel_pages_count = 0;
            copy_virt_memory(mm); // duplicate virt memory (inc contents)
        }
        // that's it, no modifying pc/sp/etc

		// user task only: dup fds (kernel tasks won't need them)
		// 		increment reference counts on open file descriptors.
		for (int i = 0; i < NOFILE; i++)
			if (current->ofile[i])
				p->ofile[i] = filedup(current->ofile[i]);
		p->cwd = idup(current->cwd);
		release(&current->lock);
    }

    // also inherit task name
	safestrcpy(p->name, current->name, sizeof(current->name));		

	p->flags = clone_flags;
	p->priority = current->priority;
	p->counter = p->priority;
	p->preempt_count = 1; //disable preemption until schedule_tail
	// p->mm.sz = current->mm.sz; p->mm.codesz = current->mm.codesz; 	// user only?? XXX move above?? XXX

	// TODO: init more field here
	// @page is 0-filled, many fields (e.g. mm.pgd) are implicitly init'd

	p->cpu_context.pc = (unsigned long)ret_from_fork;
	p->cpu_context.sp = (unsigned long)childregs;	
	p->pid = pid; 
	release(&p->lock);	

  	acquire(&wait_lock);
 	p->parent = current;
  	release(&wait_lock);

	// should be the last thing ... hence scheduler can pick up
	// acquire(&p->lock);	
	p->state = TASK_RUNNABLE;
	// release(&p->lock);	

	release(&sched_lock);

	return pid;
}

/*
   	Create 1st user task by elevating a kernel task to EL1

	Populate pt_regs for returning to user space (via kernel_exit) for the 1st time.
	Note that the actual switch will not happen until kernel_exit.

	@start: beginning of the user code (to be copied to the new task). kernel va
	@size: size of the area
	@pc: offset of the startup function inside the area
*/

int move_to_user_mode(unsigned long start, unsigned long size, unsigned long pc)
{
	struct pt_regs *regs = task_pt_regs(current);
	V("pc %lx", pc);

	regs->pstate = PSR_MODE_EL0t;
	regs->pc = pc;
	/* assumption: our toy user program will not exceed 1 page. the 2nd page will serve as the stack */
	regs->sp = USER_VA_END; // 2 *  PAGE_SIZE;  
	/* only allocate 1 code page here b/c the stack page is to be mapped on demand. 
	   this will trigger allocating the task's pgtable tree (mm.pgd)
	*/
	BUG_ON(size > PAGE_SIZE);
	void *code_page = allocate_user_page(current, 0 /*va*/, MMU_PTE_FLAGS | MM_AP_RW);
	if (code_page == 0)	{
		return -1;
	}	
	current->mm.sz = current->mm.codesz = PAGE_SIZE; // at this time, user va only covers [0,PAGE_SIZE)
	memmove(code_page, (void *)start, size); 	
	set_pgd(current->mm.pgd);

	safestrcpy(current->name, "user1st", sizeof(current->name));
	current->cwd = namei("/");
	BUG_ON(!current->cwd); 

    // (from xv6) File system initialization must be run in the context of a
    // regular process (e.g., because it calls sleep), and thus cannot
    // be run from main().
    fsinit(ROOTDEV);
	fsinit(SECONDDEV); // fat
	
	return 0;
}

/* get a task's saved registers, which are at the top of the task's kernel page. 
   these regs are saved/restored by kernel_entry()/kernel_exit(). 
*/
struct pt_regs * task_pt_regs(struct task_struct *tsk)
{
	unsigned long p = (unsigned long)tsk + THREAD_SIZE - sizeof(struct pt_regs);
	return (struct pt_regs *)p;
}
