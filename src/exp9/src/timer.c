#define K2_DEBUG_INFO 

#include "plat.h"
#include "mmu.h"
#include "utils.h"
#include "printf.h"
#include "spinlock.h"
#include "sched.h"

// current design. 
// scheduler ticks (& user sleep()) are based on arm generic timers. 
// higher precision timekeeping (e.g. ms/us delay, kernel timers) are calibrated
// and based on Arm system timers (hence only available for Rpi3, not qemu)

// below are for arm generic timers
// 10Hz (100ms per tick) is assumed by some user tests. 
// TODO could be too slow for games which renders by sleep(). 60Hz then?

#define SCHED_TICK_HZ	60 

#ifdef PLAT_VIRT
int interval = ((1 << 26) / SCHED_TICK_HZ); // (1 << 26) around 1 sec
#elif defined PLAT_RPI3QEMU
int interval = ((1 << 26) / SCHED_TICK_HZ); // (1 << 26) around 1 sec
#elif defined PLAT_RPI3
int interval = (1 * 1000 * 1000 / SCHED_TICK_HZ);
#endif

struct spinlock tickslock = {.locked = 0, .cpu=0, .name="tickslock"};
unsigned int ticks; 	// sleep() tasks sleep on this var. 

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

#if defined(PLAT_RPI3) || defined(PLAT_RPI3QEMU)
/* 
	These are for Rpi3's "system Timer". Note the caveats:
	Rpi3: System Timer works fine. Can generate intrerrupts and be used as a counter for timekeeping.
	QEMU: System Timer can be used for timekeeping. Cannot generate interrupts. 
		You may want to adjust @interval as needed
	cf: 
	https://fxlin.github.io/p1-kernel/exp3/rpi-os/#fyi-other-timers-on-rpi3
		
*/

#define N_TIMERS 20
#define CLOCKHZ	1000000	// rpi3 use 1MHz clock for system counter. 

#define TICKPERSEC (CLOCKHZ)
#define TICKPERMS (CLOCKHZ / 1000)
#define TICKPERUS (CLOCKHZ / 1000 / 1000)

static inline unsigned long current_counter() {
	// assume these two are consistent, since the clock is only 1MHz..
	return ((unsigned long) get32va(TIMER_CHI) << 32) | get32va(TIMER_CLO); 
}

////////////  delay, timekeeping 

// # of cpu cycles per ms, per us. will be tuned
static unsigned int cycles_per_ms = 0; 
static unsigned int cycles_per_us = 0; 

// use sys timer to measure: # of cpu cycles per ms 
static void sys_timer_tune_delay() {
	unsigned long cur0 = current_counter(), ms, us; 
	unsigned long ncycles = 100 * 1000 * 1000; 	// run 100M cycles. must delay >1ms
	delay(ncycles); 	
	us = (current_counter() - cur0) / TICKPERUS; 
	ms = us / 1000; 

	cycles_per_us = ncycles / us; 
	cycles_per_ms = ncycles / ms; 
	I("cycles_per_us %u cycles_per_ms %u", cycles_per_us, cycles_per_ms);
}

void ms_delay(unsigned ms) {
	BUG_ON(!cycles_per_ms);
	delay(cycles_per_ms * ms); 
}

void us_delay(unsigned us) {
	BUG_ON(!cycles_per_us);
	delay(cycles_per_us * us); 
}

// 111.222
void current_time(unsigned *sec, unsigned *msec) {
	unsigned long cur = current_counter();
	*sec =  (unsigned) (cur / TICKPERSEC); 
	cur -= (*sec) * TICKPERSEC; 
	*msec = (unsigned) (cur / TICKPERMS);	
}

#endif 


#if defined(PLAT_RPI3)
////////////// virtual kernel timers 

struct spinlock timerlock;

struct vtimer {
	TKernelTimerHandler *handler; 
	unsigned long elapseat; 	
	void *param; 
	void *context; 
}; 
static struct vtimer timers[N_TIMERS]; 

void sys_timer_test() { // will fire shortly in the future
	unsigned int curVal = get32va(TIMER_CLO);
	curVal += interval;
	put32va(TIMER_C1, curVal);	
}

void sys_timer_init(void)
{
	initlock(&timerlock, "timer"); 
	memzero(timers, sizeof(timers)); 	// all field zeros	
	sys_timer_tune_delay(); 
}

// we have added/removed a vtimer, now adjust the phys timer accordingly
// caller must hold timerlock
// return 0 on success
static int adjust_sys_timer(void)
{
	unsigned long next = 0xFFFFFFFFFFFFFFFF; // upcoming firing time

	for (int tt = 0; tt < N_TIMERS; tt++) {
		if (!timers[tt].handler)
			continue; 
		if (timers[tt].elapseat < next) {
			next = timers[tt].elapseat;
		}
	}

	BUG_ON(current_counter() > next); // next in the past; shoulda fired already

	// if no valid handlers, we leave TIMER_C1 as is. it will trigger a timer
	// irq when wrapping around (~4000 sec later). this is fine as our isr
	// compares 64bit counters. 
	if (next == 0xFFFFFFFFFFFFFFFF) 
		return 0; 

	// the compare reg is only 32 bits so we have to ignore the high 32 bits of
	// the counter. this is ok even if the low 32 bits have to wrap around 
	// in order to match TIMER_C1 (cf the isr)	
	put32va(TIMER_C1, (unsigned)next);  

	return 0; 
}

// return: timer id (>=0, <N_TIMERS) found. -1 on error
// the clock counter has 64bit, so we assume it won't wrap around
int ktimer_start(unsigned delayms, TKernelTimerHandler *handler, 
		void *para, void *context) {
	unsigned t; 
	unsigned long cur; 

	acquire(&timerlock); 

	for (t = 0; t < N_TIMERS; t++) {
		if (timers[t].handler == 0) 
			break; 
	}
	if (t == N_TIMERS) {
		release(&timerlock); 
		E("ktimer_start failed. # max timer reached"); 
		return -1; 
	}

	cur = current_counter(); 
	BUG_ON(cur + TICKPERMS * delayms < cur); // 64bit counter wraps around??

	timers[t].handler = handler; 
	timers[t].param = para; 
	timers[t].context = context; 
	timers[t].elapseat = cur + TICKPERMS * delayms; 

	adjust_sys_timer(); 

	release(&timerlock); 

	return t; 
}

// return 0 on okay, -1 if no such timer/handler, 
//	-2 if already fired (will clean anyway)
int ktimer_cancel(int t) {
	unsigned long cur; 

	if (t < 0 || t >= N_TIMERS)
		return -1; 

	cur = current_counter();
	acquire(&timerlock); 

	if (!timers[t].handler) {	// invalid handler
		release(&timerlock); 
		return -1; 
	}

	if (timers[t].elapseat < cur) { // already fired? 
		timers[t].handler = 0; 
		timers[t].context = 0; 
		timers[t].param = 0; 
		release(&timerlock); 
		return -2; 
	}

	timers[t].handler = 0; 
	// timers[t].context = 0; 
	// timers[t].param = 0; 
	// timers[t].elapseat = 0; 

	adjust_sys_timer(); 	
	release(&timerlock);

	return 0;  
}

void sys_timer_irq(void) 
{
	V("called");	

	BUG_ON(!(get32va(TIMER_CS) & TIMER_CS_M1));  // timer1 must have pending match
	put32va(TIMER_CS, TIMER_CS_M1);	// clear timer1 match

	unsigned long cur = current_counter(); 

	acquire(&timerlock); 
	for (int t = 0; t < N_TIMERS; t++) {
		TKernelTimerHandler *h = timers[t].handler; 
		if (h == 0) 
			continue; 
		if (timers[t].elapseat <= cur) { // should fire  
			timers[t].handler = 0; 
			// TODO: do callback w/o holding timerlock...
			(*h)(t, timers[t].param, timers[t].context); 
		}		
	}
	adjust_sys_timer(); 
	release(&timerlock);
}
#endif