.globl get_el
get_el:
	# Copy the value from `CurrentEL` system register into `x0` register	
	mrs x0, CurrentEL	
	# The lowest 2 bits in the `CurrentEL` register are reserved and always have value 0
	lsr x0, x0, #2
	# Finally the register `x0` contains an integer number indicating current exception level
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
