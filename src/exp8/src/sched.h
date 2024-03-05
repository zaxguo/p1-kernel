#ifndef _SCHED_H
#define _SCHED_H

#define THREAD_CPU_CONTEXT			0 		// offset of cpu_context in task_struct 

#ifndef __ASSEMBLER__

#define THREAD_SIZE				4096

#define FIRST_TASK task[0]
#define LAST_TASK task[NR_TASKS-1]

/* 
	By classic OS textbook/lectures, 
	READY means ready to run but is not running because of no idle CPU, not scheduled yet, etc. 
	RUNNING means the task is running and currently uses CPU.

	However, in the simple impl. below, 
	TASK_RUNNING represents either RUNNING or READY 
*/
#define TASK_RUNNING					0
#define TASK_SLEEPING					1
#define TASK_ZOMBIE						2
#define TASK_RUNNABLE					3
/* TODO: define more task states (as constants) below, e.g. TASK_WAIT */

#define PF_KTHREAD		            	0x00000002	

extern struct task_struct *current;
extern struct task_struct * task[NR_TASKS];
extern int nr_tasks;

// Contains values of all registers that might be different between the tasks.
struct cpu_context {
	unsigned long x19;
	unsigned long x20;
	unsigned long x21;
	unsigned long x22;
	unsigned long x23;
	unsigned long x24;
	unsigned long x25;
	unsigned long x26;
	unsigned long x27;
	unsigned long x28;
	unsigned long fp;
	unsigned long sp;
	unsigned long pc;
};

#define MAX_PROCESS_PAGES			16	  // TODO: move such defs to one place

struct user_page {
	unsigned long phys_addr;
	unsigned long virt_addr; // user va
};

// the size grows with MAX_PROCESS_PAGES, could be problem for larger user programs in the future...
struct mm_struct {
	unsigned long pgd;	// pa. NB this is loaded to ttbr0 (user va)
	int user_pages_count;
	/* keep track of which user pages are used for this task */
	struct user_page user_pages[MAX_PROCESS_PAGES];
	int kernel_pages_count;
	/* phys addrs of which (kernel) pages are used for this task, e.g. those for pgtables.  */
	unsigned long kernel_pages[MAX_PROCESS_PAGES]; 
};

// the metadata describing a task
struct task_struct {
	struct cpu_context cpu_context;	// register values
	long state;		// the state of the current task, e.g. TASK_RUNNING
	long counter;	// how long this task has been running? decreases by 1 each timer tick. Reaching 0, kernel will attempt to schedule another task. Support our simple sched
	long priority;	// when kernel schedules a new task, the kernel copies the task's  `priority` value to `counter`. Regulate CPU time the task gets relative to other tasks 
	long preempt_count; // a flag. A non-zero means that the task is executing in a critical code region cannot be interrupted, Any timer tick should be ignored and not triggering rescheduling
	unsigned long flags;
	struct mm_struct mm;
	void *chan;                  // If non-zero, sleeping on chan
	int killed;                  // If non-zero, have been killed
	int pid; 					 // still need this, ease of debugging...
	struct file *ofile[NOFILE];  // Open files
	struct inode *cwd;           // Current directory
  	char name[16];               // Process name (debugging)	
};

// bottom half a page; make sure the top half enough space for ker stack...
_Static_assert(sizeof(struct task_struct) < 2048);	

extern void sched_init(void);
extern void schedule(void);
extern void timer_tick(void);
extern void preempt_disable(void);
extern void preempt_enable(void);
extern void switch_to(struct task_struct* next);
extern void cpu_switch_to(struct task_struct* prev, struct task_struct* next);	// sched.S

void procdump(void); 

// the initial values for task_struct that belongs to the init task. see sched.c 
// NB: init task is in kernel, only has kernel mapping (ttbr1) 
// 		no user mapping (ttbr0, mm->pgd=0)
#define INIT_TASK \
/*cpu_context*/ { { 0,0,0,0,0,0,0,0,0,0,0,0,0}, \
0 /*state*/, 0 /*counter*/, 2 /*priority*/, 0 /*preempt_count*/, PF_KTHREAD, \
/* mm */ { 0, 0, {{0}}, 0, {0}}, \
0 /*chan*/, 0 /*killed*/ 		\
}
// TODO: init more fields

// --------------- processor related ----------------------- // 
// we only support 1 cpu (as of now), but xv6 code is around multicore so we keep the 
// ds here...
struct cpu {
  struct task_struct *proc;          // The process running on this cpu, or null.
  int noff;                   		// Depth of push_off() nesting.
  int intena;                 		// Were interrupts enabled before push_off()?
};

extern struct cpu cpus[NCPU];
static inline struct cpu* mycpu(void) {return &cpus[0];};
static inline struct task_struct *myproc(void) {return current;};

// --------------- fork related ----------------------- // 

/*
 * PSR bits
 */
#define PSR_MODE_EL0t	0x00000000
#define PSR_MODE_EL1t	0x00000004
#define PSR_MODE_EL1h	0x00000005
#define PSR_MODE_EL2t	0x00000008
#define PSR_MODE_EL2h	0x00000009
#define PSR_MODE_EL3t	0x0000000c
#define PSR_MODE_EL3h	0x0000000d

int copy_process(unsigned long clone_flags, unsigned long fn, unsigned long arg);
int move_to_user_mode(unsigned long start, unsigned long size, unsigned long pc);
struct pt_regs * task_pt_regs(struct task_struct *tsk);

struct pt_regs {
	unsigned long regs[31];
	unsigned long sp;
	unsigned long pc;
	unsigned long pstate;
};

#endif		// ! __ASSEMBLER__
#endif
