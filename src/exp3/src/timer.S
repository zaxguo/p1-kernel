/** Here, the physical timer at EL1 is used with the TimerValue views.
 *  Once the count-down has reach 0, the interrupt line is HIGH until
 *  a new timer value > 0 is write into the CNTP_TVAL_EL0 system register.
 *
 *  See AArch64-referenc-manual p.2326 at
 *  https://developer.arm.com/docs/ddi0487/ca/arm-architecture-reference-manual-armv8-for-armv8-a-architecture-profile
 */

.globl gen_timer_init
// Turn on the timer and allow it to generate interrupts
// 
// Note: some students observed that if at the time of writing to CNTP_CTL_EL0 the timer firing condition is met 
// (i.e. TVAL is a negative value), an interrupt will be fired immediately. 
// If you experience the same thing, you should omit the spurious interrupt.
gen_timer_init:
	mov x0, #1
	msr CNTP_CTL_EL0, x0	// writes 1 to the control register (`CNTP_CTL_EL0`) of **the EL1 physical timer**
	ret

.globl gen_timer_reset
gen_timer_reset:
// Take the 1st arugment (passed in x0) as the interval before next firing of the timer. 
// alternatively, the two lines below demonstrate how to set a fixed interval (1<<24 ticks). 
//   mov x0, #1
//	 lsl x0, x0, #24
	msr CNTP_TVAL_EL0, x0
    ret
