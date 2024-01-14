#include "mm.h"
#include "sched.h"
#include "entry.h"

// @fn: a function to execute in a new task 
// @arg: an argument passed to this function
int copy_process(unsigned long fn, unsigned long arg)
{
	struct task_struct *p;

	// Next, a new page is allocated. At the bottom of this page, we are putting 
	// the `task_struct` for the newly created task. The rest of this page will be used as the task stack.
	p = (struct task_struct *) get_free_page();
	if (!p)
		return 1;
	p->priority = current->priority;
	p->state = TASK_RUNNING;
	p->counter = p->priority;	/* inherit priority. default: 1. see sched.h */

	// Here `cpu_context` is initialized. 
	p->cpu_context.x19 = fn;
	p->cpu_context.x20 = arg;
	p->cpu_context.pc = (unsigned long)ret_from_fork;
	// The stack pointer is set to the top of the newly allocated memory page
	p->cpu_context.sp = (unsigned long)p + THREAD_SIZE;
	
	int pid = nr_tasks++;
	task[pid] = p;	
	return 0;
}
