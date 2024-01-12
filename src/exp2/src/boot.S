#include "arm/sysregs.h"

#include "mm.h"

.section ".text.boot"

.globl _start
_start:
	mrs	x0, mpidr_el1		
	and	x0, x0,#0xFF		// Check processor id
	cbz	x0, master		// Hang for all non-primary CPU
	b	proc_hang

proc_hang: 
	b 	proc_hang

master:
	ldr	x0, =SCTLR_VALUE_MMU_DISABLED // System control register
	msr	sctlr_el1, x0		

	ldr	x0, =HCR_VALUE  	// Hypervisor Configuration (EL2) 
	msr	hcr_el2, x0  

#ifdef USE_QEMU 			// QEMU boots from EL2. cannot do things to EL3			
	ldr	x0, =SPSR_VALUE		// SPSR_VALUE controls the consequence of exception return (eret), including the new exception level (EL1)
	msr	spsr_el2, x0

	// Below, elr means ``exception link register''; and elr_el2 is its copy accessible at EL2. 
	// elr_el2 points to the first instruction to be executed once the CPU reaches the new exception level after executing ``eret''.
	// In the code below, that instruction is set at label "el1_entry_another"; CPU enters EL1 and jumps to el1_entry_another. 
	// In fact you can point elr_el2 to any instruction, e.g. an inf loop. 
	//
	// 		Aside: There's a general purpose register called LR (link register). A function call is often done 
	//			via BL (branch with link), which stores the return address in LR; 
	// 			function return is done via "BX LR" (unconditional jump to the addr in LR). ELR has some similarity 
	//			to LR, barring that ELR stores the return address for eret
	//
	// 		Aside: Now you tweak spsr_el2 so that the CPU will switch to EL0. But if the code following el1_entry_another contains 
	//				instructions that are illegal at EL0 (e.g. MSR/MRS), CPU will trigger exceptions. 
	//			    And since you haven't implemented any exception handlers, the kernel will enter la-la land...	

	#adr	x0, el1_entry
	adr x0, el1_entry_another
	msr	elr_el2, x0
#else 					// Rpi3 hw boots from EL3. 
	ldr	x0, =SCR_VALUE	// Secure config register. Only at EL3.
	msr	scr_el3, x0

	ldr	x0, =SPSR_VALUE
	msr	spsr_el3, x0

	adr	x0, el1_entry		
	msr	elr_el3, x0
#endif
  
	eret				

el1_entry:
	adr	x0, bss_begin
	adr	x1, bss_end
	sub	x1, x1, x0
	bl 	memzero

el1_entry_another:
	mov	sp, #LOW_MEMORY
	bl	kernel_main
	b 	proc_hang		// should never come here
