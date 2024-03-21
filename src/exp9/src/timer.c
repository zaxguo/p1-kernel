#include "utils.h"
#include "printf.h"
#include "sched.h"

// 10Hz (100ms per tick) is assumed by some user tests.
#ifdef PLAT_VIRT
int interval = ((1 << 26) / 10); // (1 << 26) around 1 sec
#elif defined PLAT_RPI3QEMU
int interval = ((1 << 26) / 10); // (1 << 26) around 1 sec
#elif defined PLAT_RPI3
int interval = (1 * 1000 * 1000 / 10);
#endif

struct spinlock tickslock = {.locked = 0, .cpu=0, .name="tickslock"};
unsigned int ticks; 	// sleep() tasks sleep on this var

/* 	These are for Arm generic timers. 
	They are fully functional on both QEMU and Rpi3.
	Recommended.
*/
void generic_timer_init ( void )
{
	gen_timer_init();
	gen_timer_reset(interval);	// kickoff 1st time firing
}

void handle_generic_timer_irq( void ) 
{
	// TODO: In order to implement sleep(t), you should calculate @interval based on t, 
	// instead of having a fixed @interval which triggers periodic interrupts
	
	acquire(&tickslock); 
	ticks++; 
	wakeup(&ticks); 
	release(&tickslock);

	gen_timer_reset(interval);
	timer_tick();
}
