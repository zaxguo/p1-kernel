// ----------------- irq --------------------------- //

.globl irq_vector_init
irq_vector_init:
	adr	x0, vectors		// load VBAR_EL1 with virtual
	msr	vbar_el1, x0		// vector table address
	ret

.globl enable_irq
enable_irq:
	msr    daifclr, #2 
	ret

.globl disable_irq
disable_irq:
	msr	daifset, #2
	ret

// ----------------- arm generic timer  --------------------------- //

/** 
	Here, the physical timer at EL1 is used with the TimerValue views.
 *  Once the count-down reaches 0, the interrupt line is HIGH until
 *  a new timer value > 0 is written into the CNTP_TVAL_EL0 system register.
 *
 *  Read: 
 *  https://fxlin.github.io/p1-kernel/exp3/rpi-os/#arms-generic-hardware-timer
 * 
 *  Reference: AArch64-referenc-manual p.2326 at
 *  https://developer.arm.com/docs/ddi0487/ca/arm-architecture-reference-manual-armv8-for-armv8-a-architecture-profile
 */

.globl gen_timer_init
gen_timer_init:
	# Below, writes 1 to the control register (CNTP_CTL_EL0) of the EL1 physical timer
	# Explanation: 
	# 		CTL indicates this is a control register
	#		CNTP_XXX_EL0 indicates that this is for the EL1 physical timer
	#		(Why named _EL0? I guess it means that the timer is accessible to both EL1 and EL0)
	mov x0, #1
	msr CNTP_CTL_EL0, x0
	ret

.globl gen_timer_reset
gen_timer_reset:
	# When called from C code, the function writes the 1st argument (x0) to TVAL, 
	# which (roughly speaking) sets a "delta" for System Counter.
	msr CNTP_TVAL_EL0, x0
    ret


// ---------------------- misc -------------------------------------------- //
.globl get_el
get_el:
	mrs x0, CurrentEL
	lsr x0, x0, #2
	ret

.globl put32
put32:
	str w1,[x0]
	ret

.globl get32
get32:
	ldr w0,[x0]
	ret

.globl delay
delay:
	subs x0, x0, #1
	bne delay
	ret