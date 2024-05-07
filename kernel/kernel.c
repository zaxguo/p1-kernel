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
extern void test_kernel_tasks();

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
	test_kernel_tasks(); 
	while (1);

	printf("Kernel process started at EL %d, pid %d\r\n", get_el(), myproc()->pid);
	int err = move_to_user_mode(begin, end - begin, process - begin);
	if (err < 0){
		printf("Error while moving process to user mode\n\r");
	} 
	// this func is called from ret_from_fork (entry.S). after returning, it goes back to 
	// ret_from_fork and does kernel_exit there. hence, pt_regs populated by move_to_user_mode()
	// will take effect. 
}

unsigned long * spin_cpu = PA2VA(0xd8);  // boot.S
extern unsigned long core_flags[4];  // boot.S
extern unsigned long core2_state[4];  // boot.S
extern unsigned long _start;

// static struct spinlock testlock = {.locked=0, .cpu=0, .name="test_lock"};

void uart_send_string(char* str);
void secondary_core(int core_id)
{
	uart_send_string("secondary_core()\n");

	printf("Hello from core %d", core_id);

	generic_timer_init(); 
	enable_interrupt_controller(core_id);
	enable_irq();
	while (1)
		asm volatile("wfi"); 
}

__attribute__((unused))
static void start_cores(void) {		
	// Flush the whole kernel memory 
	// My theory: cpu1+ were down when cpu0 was init kernel state; so they might
	// have missed cache transactions and therefore could see stale kernel states
	// e.g. cpu1+ couldn't see the effect of init_printf() and hence failed to 
	// print msgs. 
	__asm_flush_dcache_range((void *)VA_START,  (void*)VA_START + DEVICE_BASE); 

	for (int i=1; i <NCPU; i++) {
#ifdef PLAT_RPI3QEMU		
		spin_cpu[i] = VA2PA(&_start); 
#endif		
		core_flags[i] = 1; 
		__asm_flush_dcache_range(spin_cpu, spin_cpu+4);
		__asm_flush_dcache_range(core_flags, core_flags+4);
		asm volatile ("sev");
	}
}

// extern unsigned long _start;
extern void uart_send_va(char c); 
extern void uart_send_pa(char c); 
void kernel_main()
{
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
	// irq_vector_init();
	generic_timer_init(); 	// for sched ticks
	sys_timer_init(); 		// for kernel timer
	enable_interrupt_controller(0/*coreid*/);
	enable_irq();
	
	if (usbkb_init() == 0) I("usb kb init done"); 

	int res = copy_process(PF_KTHREAD, (unsigned long)&kernel_process, 0/*arg*/);
	if (res < 0) {
		printf("error while starting kernel process");
		return;
	}

	// start other cores after all subsystems are init'd 
	start_cores(); 

	int wpid; 
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
