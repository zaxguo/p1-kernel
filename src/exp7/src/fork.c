#include "utils.h"
#include "sched.h"
#include "entry.h"

int copy_process(unsigned long clone_flags, unsigned long fn, unsigned long arg)
{
	preempt_disable();
	struct task_struct *p;

	p = (struct task_struct *) kalloc();  // get kernel va
	struct pt_regs *childregs = task_pt_regs(p);

	if (!p)
		return -1;

	if (clone_flags & PF_KTHREAD) { /* create a kernel task */
		p->cpu_context.x19 = fn;
		p->cpu_context.x20 = arg;
	} else { /* fork user tasks */
		struct pt_regs * cur_regs = task_pt_regs(current);
		*cur_regs = *childregs; 	// copy over the entire pt_regs
		childregs->regs[0] = 0;		// return value (x0) for child
		copy_virt_memory(p);		// duplicate virt memory (inc contents)
		// that's it, no modifying pc/sp/etc
	}
	p->flags = clone_flags;
	p->priority = current->priority;
	p->state = TASK_RUNNABLE;
	p->counter = p->priority;
	p->preempt_count = 1; //disable preemption until schedule_tail
	// TODO: init more field here
	// @page is 0-filled, many fields (e.g. mm.pgd) are implicitly init'd

	p->cpu_context.pc = (unsigned long)ret_from_fork;
	p->cpu_context.sp = (unsigned long)childregs;
	int pid = nr_tasks++;  // xzl: TODO need to recycle pid.
	task[pid] = p;	 
	p->pid = pid; 

	preempt_enable();
	return pid;
}


/* 
   Populate pt_regs for returning to user space (via kernel_exit) for the 1st time. 
   Note that the actual switch will not happen until kernel_exit. 

	Create the user init task. 

   @start: beginning of the user code (to be copied to the new task). kernel va
   @size: size of the area 
   @pc: offset of the startup function inside the area
*/   

int move_to_user_mode(unsigned long start, unsigned long size, unsigned long pc)
{
	struct pt_regs *regs = task_pt_regs(current);
	regs->pstate = PSR_MODE_EL0t;
	regs->pc = pc;
	/* assumption: our toy user program will not exceed 1 page. the 2nd page will serve as the stack */
	regs->sp = 2 *  PAGE_SIZE;  
	/* only allocate 1 code page here b/c the stack page is to be mapped on demand. 
	   this will trigger allocating the task's pgtable tree (mm.pgd)
	*/
	void *code_page = allocate_user_page(current, 0 /*va*/);
	if (code_page == 0)	{
		return -1;
	}
	memmove(code_page, (void *)start, size); 
	set_pgd(current->mm.pgd);

	safestrcpy(current->name, "initcode", sizeof(current->name));
	current->cwd = namei("/");
	assert(current->cwd); 

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
