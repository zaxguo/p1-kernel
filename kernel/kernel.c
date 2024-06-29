// #define K2_DEBUG_VERBOSE
#define K2_DEBUG_WARN

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
extern void test_kernel_tasks();
extern void test_spinlock();

// 1st user process
extern unsigned long user_begin;	// cf the linker script
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
	test_kernel_tasks(); while (1);
	// test_spinlock(); while (1);

	printf("Kernel process started at EL %d, pid %d\r\n", get_el(), myproc()->pid);
	int err = move_to_user_mode(begin, end - begin, process - begin);
	if (err < 0){
		printf("Error while moving process to user mode\n\r");
	} 
	// this func is called from ret_from_fork (entry.S). after returning from 
	// this func, it goes back to ret_from_fork and performs kernel_exit there. 
	// hence, trampframe populated by move_to_user_mode() will take effect. 
}

// unsigned long *core_flags_pa = (unsigned long *)VA2PA(core_flags);

static struct spinlock testlock0 = {.locked=0, .cpu=0, .name="testlock"};
// static spinlock_t testlock = {.lock=0};
// volatile int flag = 0; 

void uart_send_string(char* str);

extern unsigned long pg_dir; 
#define N 4
void dump_pgdir(void) {
	unsigned long *p = &pg_dir; 

	printf("PGD va %lx\n", (unsigned long)&pg_dir); 
	for (int i =0; i<N; i++)
		printf("	PGD[%d] %lx\n", i, p[i]); 
	
	p += (4096/sizeof(unsigned long)); 
	printf("PUD va %lx\n", (unsigned long)p); 
	for (int i =0; i<N; i++)
		printf("	PUD[%d] %lx\n", i, p[i]); 

	p += (4096/sizeof(unsigned long)); 
	printf("PMD va %lx\n", (unsigned long)p); 
	for (int i =0; i<N; i++)
		printf("	PMD[%d] %lx\n", i, p[i]); 

	p += (4096/sizeof(unsigned long)); 
	printf("PMD va %lx\n", (unsigned long)p); 
	for (int i =0; i<N; i++)
		printf("	PMD[%d] %lx\n", i, p[i]); 		


	unsigned long nFlags;
	asm volatile ("mrs %0, sctlr_el1" : "=r" (nFlags));
	printf("sctlr_el1 %016lx\n", nFlags); 
	asm volatile ("mrs %0, tcr_el1" : "=r" (nFlags));
	printf("tcr_el1 %016lx\n", nFlags); 
}

// the table used by firmware that wants to "park" the cores. implemented by:
// 	 rpi3 firmware (https://github.com/raspberrypi/tools/tree/master/armstubs)
//   qemu 
unsigned long *core_flags = (unsigned long *)PA2VA(0x000000D8); 

// called from boot.S, after setting up sp, MMU, pgtables, etc
void secondary_core(int core_id)
{
	// W("coreflags %lx %lx %lx %lx", core_flags[0], core_flags[1], core_flags[2], 
	// 	core_flags[3]);

	dump_pgdir();
	
	core_flags[core_id] = 0; // notifying cpu0: this cpu has MMU up, so cpu0 can go

	// __asm_flush_dcache_range((unsigned long*)core_flags+core_id, 
	// 	(unsigned long*)core_flags+core_id+1);

	printf("11111111111111111\n");

	for (int i=0; i<10;i++) {
		acquire(&testlock0);
		// __asm_flush_dcache_range(&testlock, (char *)&testlock+4);

		// do {
		// 	__asm__ volatile ("dmb sy" ::: "memory");    // mem barrier, ensuring msg in mem
		// 	printf("X");
		// } while (flag != 0); 
		// flag = 1; 
		// __asm_flush_dcache_range((void *)&flag, (char *)&flag+4);
		// __asm__ volatile ("dmb sy" ::: "memory");    // mem barrier, ensuring msg in mem

		printf("Hello core %d\n", core_id);		
		release(&testlock0);
	}
	W("coreflags %lx %lx %lx %lx", core_flags[0], core_flags[1], core_flags[2], 
		core_flags[3]);
	// W("coreflags pa %lx %lx %lx %lx", core_flags_pa[0], core_flags_pa[1], core_flags_pa[2], 
	// 	core_flags_pa[3]);		

	while (1); 

	// acquire(&testlock0); 
	// printf("Hello core %d\n", core_id);

	generic_timer_init(); 
	enable_interrupt_controller(core_id);
	enable_irq();
	// so far, on boot stack and as the "idle" task
	schedule(); 
	while (1)	// cf kernel_main()
		asm volatile("wfi"); 
}

extern unsigned long _start;  // boot.S

static void start_cores(void) {		
	// cpu0: Flush the whole kernel memory (must)
	// My theory: cpu1+ were down when cpu0 was init kernel state; so they might
	// have missed cache transactions and therefore could see stale kernel states
	// e.g. cpu1+ couldn't see the effect of init_printf() and hence failed to 
	// print msgs. 
	__asm_flush_dcache_range((void *)VA_START,  (void*)VA_START + DEVICE_BASE); 

	// wake up cpu1+ by changing core_flags
	for (int i=1; i <NCPU; i++) 
		core_flags[i] = VA2PA(&_start); // cpu1+ run from _start
	__asm_flush_dcache_range((unsigned long*)core_flags, 
		(unsigned long*)core_flags+4);
	__asm_flush_dcache_range((void *)VA_START,  (void*)VA_START + DEVICE_BASE); 

	asm volatile ("dsb sy");
	asm volatile ("sev");
	
	int timeout=100; 
	for (int i=1; i <NCPU; i++) {
		while (core_flags[i]) {
			if (timeout-- <= 0) {
				E("failed to start core %d", i); 
				E("coreflags %lx %lx %lx %lx", core_flags[0], core_flags[1], core_flags[2], 
					core_flags[3]);
				BUG(); 
			}
			ms_delay(1); 
		}
	}
	W("start cores ok");
}

extern void uart_send_va(char c); 
extern void uart_send_pa(char c); 

// core0 only
void kernel_main() {
	uart_init();
	init_printf(NULL, putc);	
	printf("------ kernel boot ------ %d\n\r", (int)cpuid());
		
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
	// generic_timer_init(); 	// for sched ticks
	sys_timer_init(); 		// for kernel timer
	enable_interrupt_controller(0/*coreid*/);
	enable_irq();	// after this, scheduler is on
	
	if (usbkb_init() == 0) I("usb kb init done"); 
	
	// dump_pgdir();

	// start other cores after all subsystems are init'd 
	start_cores(); 

	// ms_delay(50); 
	
	for (int i =0; i<10;i++)  {
		acquire(&testlock0);
		// __asm_flush_dcache_range(&testlock, (char *)&testlock+4);
		// printf("core0....\n");
		printf("0000000000000\n");
		release(&testlock0);
		// __asm_flush_dcache_range(&testlock, (char *)&testlock+4);

		// do {
		// __asm__ volatile ("dmb sy" ::: "memory");    // mem barrier, ensuring msg in mem
		// } while (flag != 0); 
		// flag = 1;  __asm_flush_dcache_range((void *)&flag, (char *)&flag+4);
		// printf("core0....\n");		
		// uart_send_string("0000000000000\n");
		// flag = 0;  __asm_flush_dcache_range((void *)&flag, (char *)&flag+4);
		// __asm__ volatile ("dmb sy" ::: "memory");    // mem barrier, ensuring msg in mem

		
		// acquire(&testlock0); 
		// printf("core0....\n");
		// release(&testlock0);
	}		

	generic_timer_init(); 	// for sched ticks

	// now cpu is on its boot stack (boot.S) belonging to the idle task
	// schedule() will jump off to kernel stacks belonging to normal tasks
	// (i.e. init_task as set up in sched_init(), sched.c)
	schedule(); 
	// only when scheduler has no normal tasks to run for the current cpu,
	// the cpu switches back to the boot stack and returns here
    while (1) {
        // don't call schedule(), otherwise each irq calls schedule(): too much
        // instead, let timer_tick() throttle & decide when to call schedule()
        V("idle task");
        asm volatile("wfi");
    }
}

// the 1st normal task to created by sched_init()
void init(int arg/*ignored*/) {
	int wpid; 
    W("entering init");

	int res = copy_process(PF_KTHREAD, (unsigned long)&kernel_process, 0/*arg*/);
	if (res < 0) {
		printf("error while starting kernel process");
		return;
	}
        
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