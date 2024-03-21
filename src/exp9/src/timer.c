#include "plat.h"
#include "mmu.h"
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

// utils.S
extern void gen_timer_init();
extern void gen_timer_reset(int interval); 

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

#if defined(PLAT_RPI3) 
/* 
	These are for Rpi3's "system Timer". Note the caveats:
	Rpi3: System Timer works fine. Can generate intrerrupts and be used as a counter for timekeeping.
	QEMU: System Timer can be used for timekeeping. Cannot generate interrupts. 
		You may want to adjust @interval as needed
	cf: 
	https://fxlin.github.io/p1-kernel/exp3/rpi-os/#fyi-other-timers-on-rpi3
*/
static unsigned int curVal = 0;
void sys_timer_init(void)
{
	curVal = get32va(TIMER_CLO);
	curVal += interval;
	put32va(TIMER_C1, curVal);
}

void sys_timer_irq(void) 
{
	W("called");
	curVal += interval;
	put32va(TIMER_C1, curVal);		// set interval
	put32va(TIMER_CS, TIMER_CS_M1);	// kick timer1 again
}
#endif