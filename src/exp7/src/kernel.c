#include <stddef.h>
#include <stdint.h>

#include "utils.h"
#include "sched.h"
#include "sys.h"
#include "user.h"

// main body of kernel thread
void kernel_process() {
	printf("Kernel process started at EL %d\r\n", get_el());
	unsigned long begin = (unsigned long)&user_begin;  	// defined in linker-qemu.ld
	unsigned long end = (unsigned long)&user_end;
	unsigned long process = (unsigned long)&user_process;
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
	uart_init(VA_START + UART_PHYS);
	init_printf(NULL, putc);

	printf("kernel boots ...\n\r");

	consoleinit(); 	
	binit();         // buffer cache
    iinit();         // inode table
    fileinit();      // file table
    virtio_disk_init(); // emulated hard disk

	irq_vector_init();
	generic_timer_init();
	enable_interrupt_controller();
	enable_irq();

	printf("%s:%d called\n", __func__, __LINE__);

	int res = copy_process(PF_KTHREAD, (unsigned long)&kernel_process, 0);
	if (res < 0) {
		printf("error while starting kernel process");
		return;
	}

	printf("%s:%d called\n", __func__, __LINE__);

	while (1){
		schedule();
	}	
}