#include "mm.h"

# specify that everything defined in boot.S should go in the .text.boot section. 
.section ".text.boot"

# this section is placed at the beginning of the kernel image by the linker script
# when the kernel is started, execution begins at the `start` function
.globl _start
_start:

	# Rpi3 has 4 cores, and after the device is powered on, each core begins to 
	# execute the same code. Our kernel only works with the first one and put
	# all of the other cores in an endless loop. 

	# Get the processor ID from the [mpidr_el1](http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0500g/BABHBJCI.html) 
	# system register. 	
	mrs	x0, mpidr_el1		
	and	x0, x0, #0xFF		// Check processor id
	cbz	x0, master			// Hang for all non-primary CPU. cbz=jump if result of previously executed operation == 0
	b	proc_hang

proc_hang: 
	b 	proc_hang

# If the current processor ID is 0, then execution branches to the `master` function
master:

	# Here, we clean the `.bss` section by calling `memzero`. 
	# In ARMv8 architecture, by convention, the first seven arguments are passed to 
	# the called function via registers x0–x6. 
	# The `memzero` function accepts only two arguments: the start address (`bss_begin`) 
	# and the size of the section needed to be cleaned (`bss_end - bss_begin`).
	#	bss_begin/end are defined in the linker script
	adr	x0, bss_begin
	adr	x1, bss_end
	sub	x1, x1, x0
	bl 	memzero

	# After cleaning the `.bss` section, the kernel initializes the stack pointer and 
	# passes execution to the `kernel_main` function. The Rpi3 loads the kernel at address 0 
	# (QEMU loads at 0x80000); that's why the initial stack pointer can be set to 
	# any location high enough so that stack will not override the kernel image when 
	# it grows sufficiently large. `LOW_MEMORY` (mm.h) is defined to be 4MB.
	# As our kernel's stack won't grow very large and the code/data itself is 
	# tiny, 4MB is more than enough for us. 

	mov	sp, #LOW_MEMORY 
	bl	kernel_main		// c function, kernel.c
	b 	proc_hang		// should never reach here
