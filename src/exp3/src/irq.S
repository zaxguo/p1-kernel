.globl irq_vector_init

// Making CPU aware of the vector table
// set vbar_el1 (vector table address regsiter) to the vector table address (``vectors''')
irq_vector_init:
	adr	x0, vectors			
	msr	vbar_el1, x0		
	ret


// Explanation on DAIF: ARM processor state (PSTATE) has 4 bits holding mask status for different types of interrupts. 
// **D**  Masks debug exceptions. These are a special type of synchronous exceptions. For obvious reasons, it is not possible to mask all synchronous exceptions, but it is convenient to have a separate flag that can mask debug exceptions.
// **A** Masks `SErrors`. It is called `A` because `SErrors` sometimes are called asynchronous aborts.
// **I** Masks `IRQs`
// **F** Masks `FIQs`

.globl enable_irq
enable_irq:
	msr daifclr, #2		// clear DAIF mask with 0010, i.e. clear I, which enables IRQs
	ret

.globl disable_irq
disable_irq:
	msr	daifset, #0xf	// set DAIF mask with 1111, i.e. disable all types. you may do #2 which suffices
	ret
