#define K2_DEBUG_VERBOSE

#include <stddef.h>
#include <stdint.h>

#include "plat.h"
#include "utils.h"
#include "mmu.h"
#include "sched.h"
#include "sys.h"
#include "user.h"

static void handler(TKernelTimerHandle hTimer, void *param, void *context) {
	I("called. htimer %d, param %lx, contex %lx", hTimer, (unsigned long)param, 
		(unsigned long)context); 
}

// to be called in a kernel process
static void ktimer_test() {
	unsigned sec, msec; 

	current_time(&sec, &msec); 
	I("%u.%03u start delaying 500ms...", sec, msec); 
	ms_delay(500); 
	current_time(&sec, &msec);
	I("%u.%03u ended delaying 500ms", sec, msec); 

	int t = sys_timer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
	I("timer start. timer id %d", t); 
	ms_delay(1000);
	I("timer %d should have fired", t); 

	t = sys_timer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
	I("timer start. timer id %d", t);
	ms_delay(100); 
	int c = sys_timer_cancel(t); 
	I("timer cancel return val = %d", c);
	BUG_ON(c != 0);

	I("there shouldn't be more callback"); 

	while (1)	
		; 	// spin forever 
}

// main body of kernel thread
void kernel_process() {
	unsigned long begin = (unsigned long)&user_begin;  	// defined in linker-qemu.ld
	unsigned long end = (unsigned long)&user_end;
	unsigned long process = (unsigned long)&user_process;

	ktimer_test(); 

	printf("Kernel process started at EL %d, pid %d\r\n", get_el(), current->pid);
	int err = move_to_user_mode(begin, end - begin, process - begin);
	if (err < 0){
		printf("Error while moving process to user mode\n\r");
	} 
	// this func is called from ret_from_fork (entry.S). after returning, it goes back to 
	// ret_from_fork and does kernel_exit there. hence, pt_regs populated by move_to_user_mode()
	// will take effect. 
}

void kernel_main()
{
	uart_init();
	init_printf(NULL, putc);

	printf("kernel boots ...\n\r");

	paging_init(); 
	W("here");
	consoleinit(); 	
	W("here");
	binit();         // buffer cache
	W("here");
    iinit();         // inode table
	W("here");
    fileinit();      // file table
	W("here");
	ramdisk_init(); 	// ramdisk - blk dev1
#ifdef PLAT_VIRT	
    virtio_disk_init(); // emulated hard disk - blk dev2
#endif
	irq_vector_init();
	W("here");
	generic_timer_init(); 	// for sched ticks
	sys_timer_init(); 		// for kernel timer, we shouldn't miss its 1st irq...
	enable_interrupt_controller();
	W("here");
	enable_irq();
	W("here");
	
	int res = copy_process(PF_KTHREAD, (unsigned long)&kernel_process, 0);
	if (res < 0) {
		printf("error while starting kernel process");
		return;
	}

	int wpid; 
	while (1) {
		// schedule();
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
