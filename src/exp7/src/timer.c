#include "utils.h"
#include "printf.h"
#include "sched.h"

#ifdef USE_QEMU
int interval = ((1 << 26) / 10); // xzl: (1 << 26) around 1 sec
#else
int interval = 1 * 1000 * 1000; // xzl: around 1 sec
#endif

/* 	These are for Arm generic timers. 
	They are fully functional on both QEMU and Rpi3.
	Recommended.
*/
void generic_timer_init ( void )
{
	gen_timer_init();
}

void handle_generic_timer_irq( void ) 
{
	// TODO: In order to implement sleep(t), you should calculate @interval based on t, 
	// instead of having a fixed @interval which triggers periodic interrupts
	gen_timer_reset(interval);	
	timer_tick();
}
