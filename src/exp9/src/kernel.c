#define K2_DEBUG_VERBOSE

#include <stddef.h>
#include <stdint.h>

#include "plat.h"
#include "utils.h"
#include "mmu.h"
#include "sched.h"

// unittests.c
extern void test_ktimer(); 
extern void test_malloc(); 
extern void test_mbox(); 
extern void test_usb_kb(); 
extern void test_usb_storage(); 
extern void test_fb(); 
extern void test_sound(); 
extern void test_sd(); 

// 1st user process
extern unsigned long user_begin;	// linker script
extern unsigned long user_end;
extern void user_process(); // user.c

// main body of kernel thread
void kernel_process() {
	unsigned long begin = (unsigned long)&user_begin;  	// defined in linker-qemu.ld
	unsigned long end = (unsigned long)&user_end;
	unsigned long process = (unsigned long)&user_process;

	// test_ktimer(); while (1); 
	// test_malloc(); while (1); 
	// test_mbox(); while (1); 
	// test_usb_kb(); while (1); 
	// test_usb_storage(); while (1); 
	// test_fb(); while (1); 
	// test_sound(); while (1); 
	// test_sd(); while (1); 

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

	printf("------ kernel boots ------ \n\r");
	
	paging_init(); 
	fb_init(); 		// reserve fb memory other page allocations
	consoleinit(); 	
	binit();         // buffer cache
    iinit();         // inode table
    fileinit();      // file table
	ramdisk_init(); 	// ramdisk - blk dev1
#ifdef PLAT_VIRT	
    virtio_disk_init(); // emulated hard disk - blk dev2
#endif
	irq_vector_init();
	generic_timer_init(); 	// for sched ticks
	sys_timer_init(); 		// for kernel timer
	enable_interrupt_controller();
	enable_irq();
	
	if (usbkb_init() == 0) I("usb kb init done"); 

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
