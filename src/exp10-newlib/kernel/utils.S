// ----------------- irq --------------------------- //

.globl irq_vector_init
irq_vector_init:
	adr	x0, vectors		// load VBAR_EL1 with virtual
	msr	vbar_el1, x0		// vector table address
	ret

// daifclr/set 
.globl enable_irq
enable_irq:
	msr    daifclr, #0b0010 
	ret

.globl disable_irq
disable_irq:
	msr	daifset, #0b0010 
	ret 

.global is_irq_masked
is_irq_masked:
	# xzl: whereas daifset/clr are lowest four bits, daif seems bit9--6
	# https://developer.arm.com/documentation/ddi0601/2023-12/AArch64-Registers/DAIF--Interrupt-Mask-Bits
	mrs x0, daif 
	lsr x0, x0, #7 
	and x0, x0, #1
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

// ----------------------- pgd --------------------------------------------//
// ttbr0, user va
.globl set_pgd
set_pgd:
	msr	ttbr0_el1, x0
	tlbi vmalle1is
  	DSB ISH              // ensure completion of TLB invalidation
	isb
	ret

.globl get_pgd
get_pgd:
	mov x1, 0
	ldr x0, [x1]
	mov x0, 0x1000
	msr	ttbr0_el1, x0
	ldr x0, [x1]
	ret

// ---------------------- misc -------------------------------------------- //
.globl memcpy
memcpy:
	ldr x3, [x1], #8
	str x3, [x0], #8
	subs x2, x2, #8
	b.gt memcpy
	ret

.globl memzero
memzero:
	str xzr, [x0], #8
	subs x1, x1, #8
	b.gt memzero
	ret

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

// aarch64 cache ops, from Rt thread OS
// https://raw.githubusercontent.com/RT-Thread/rt-thread/master/libcpu/aarch64/common/cache.S

/*
 * void __asm_flush_dcache_range(start, end)
 *
 * clean & invalidate data cache in the range
 *
 * x0: start address
 * x1: end address
  * (xzl: both VA, "dc civac" - dc cache and/or inv by VA)
 */
.globl __asm_flush_dcache_range
__asm_flush_dcache_range:
    mrs    x3, ctr_el0
    lsr    x3, x3, #16
    and    x3, x3, #0xf
    mov    x2, #4
    lsl    x2, x2, x3        /* cache line size */

    /* x2 <- minimal cache line size in cache system */
    sub    x3, x2, #1
    bic    x0, x0, x3

1:  dc    civac, x0    /* clean & invalidate data or unified cache */
    add    x0, x0, x2
    cmp    x0, x1
    b.lo    1b
    dsb    sy
    ret

/* void __asm_invalidate_dcache_range(start, end)
 *
 * invalidate data cache in the range
 *
 * x0: start address
 * x1: end address
 */
.globl __asm_invalidate_dcache_range
__asm_invalidate_dcache_range:
    mrs    x3, ctr_el0
    lsr    x3, x3, #16
    and    x3, x3, #0xf
    mov    x2, #4
    lsl    x2, x2, x3        /* cache line size */

    /* x2 <- minimal cache line size in cache system */
    sub    x3, x2, #1
    bic    x0, x0, x3

1:  dc   ivac, x0    /* invalidate data or unified cache */
    add    x0, x0, x2
    cmp    x0, x1
    b.lo    1b
    dsb    sy
    ret
