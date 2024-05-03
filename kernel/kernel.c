#define K2_DEBUG_VERBOSE

#include <stddef.h>
#include <stdint.h>

#include "plat.h"
#include "utils.h"
#include "mmu.h"
#include "sched.h"

// needed by boot.S
__attribute__ ((aligned (4096))) \
	char kernel_stack_start[PAGE_SIZE * NPAGES_PER_KERNEL_STACK * NCPU];

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
	// test_sd(); while (1); 	// works for both rpi3 hw & qemu

	printf("Kernel process started at EL %d, pid %d\r\n", get_el(), current->pid);
	int err = move_to_user_mode(begin, end - begin, process - begin);
	if (err < 0){
		printf("Error while moving process to user mode\n\r");
	} 
	// this func is called from ret_from_fork (entry.S). after returning, it goes back to 
	// ret_from_fork and does kernel_exit there. hence, pt_regs populated by move_to_user_mode()
	// will take effect. 
}

// extern unsigned long *spin_cpu1;  // boot.S
extern unsigned long spin_cpu0[4];  // boot.S
extern unsigned long core_flags[4];  // boot.S
extern unsigned long core2_state[4];  // boot.S
extern unsigned long start0;

void uart_send_string(char* str);
void secondary_core(int core_id)
{
	core2_state[2] = 0xffff000000846000; 
	uart_send_string("secondary_core()");
	__asm_flush_dcache_range(core2_state, core2_state+4);

	// not useful
	// __asm_invalidate_dcache_range((void*)VA_START, (void*)VA_START+0x10000000);
	// init_printf(NULL, putc);

	printf("hello");
	uart_send_string("2nd core again");
	printf("Hello from core %d\n", core_id);
	while (1)
		;
}

static void start_core(int coreid) {
	// only needed for executing on qemu 
	// does not affect execution on real hw
	// *(unsigned long *)(0xd8UL + coreid*8) = (unsigned long)&start0; 
	spin_cpu0[coreid] = VA2PA(&start0); 
	core_flags[coreid] = 1; 
	__asm_flush_dcache_range(spin_cpu0, spin_cpu0+4);
	__asm_flush_dcache_range(core_flags, core_flags+4);
	asm volatile ("sev");
}

// extern unsigned long _start;
extern void uart_send_va(char c); 
extern void uart_send_pa(char c); 
void kernel_main()
{
	if (cpuid() == 0) {
		uart_init();
		init_printf(NULL, putc);
		__asm_flush_dcache_range((void *)0xffff00000080e358, 
			(void *)0xffff00000080e358+8); // must flush printf ptr.. otherwise core1 wont see
		printf("------ kernel boots111 ------ %d\n\r", (int)cpuid());
		// for (int i =0; i<5;i++)
		// 	uart_send_va('c');
		// printf("here");
	} else {
		printf("------ kernel boots ------ %d\n\r", (int)cpuid());
	}
	
	start_core(1);
	// if (cpuid()==0) {	// works
	// 	put32va(0xe0, VA2PA(&start0)); 	// let core1 go
	// 	put32va(0xe8, VA2PA(&start0)); 	// let core2 go
	// 	put32va(0xf0, VA2PA(&start0)); 	// let core3 go
	// 	__asm_flush_dcache_range(PA2VA(0xe0), PA2VA(0xff));
	// }

	while (1) {
		// printf("%lx\n", (unsigned long *)PA2VA(0xe0));
		// delay(100*100000);
		// printf("core2 state %lx %lx %lx %lx\n", 
		// 	core2_state[0],core2_state[1],core2_state[2],core2_state[3]);
		;
	}
	
	paging_init(); 
	sched_init(); I("sched_init done"); // must be before schedule() or timertick() 
	fb_init(); 		// reserve fb memory other page allocations
	consoleinit(); 	
	binit();         // buffer cache
    iinit();         // inode table
    fileinit();      // file table
	ramdisk_init(); 	// ramdisk - blk dev1
#ifdef PLAT_VIRT	
    virtio_disk_init(); // emulated hard disk - blk dev2
#endif
	if (sd_init()!=0) E("sd init failed");
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
