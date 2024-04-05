ARMGNU ?= aarch64-linux-gnu

ULIB = ulib.o printf.o usys_s.o umalloc.o tinyprintf.o uio.o

UPROGS = \
	build/echo \
	build/ls \
	build/mkdir \
	build/forktest \
	build/usertests \
	build/sh	\
	build/cat	\
	build/grep	\
	build/kill	\
	build/ln	\
	build/rm	\
	build/wc	\
	build/slider	\
	build/nes 

sd.bin: $(UPROGS) mkfs	
	cd build && ../mkfs ../sd.bin `ls`

COPS = -MMD -Wall -Werror -nostdlib -g -fno-omit-frame-pointer
COPS += -nostartfiles -ffreestanding -mgeneral-regs-only
COPS += -O0

.PRECIOUS: $(ULIB)

mkfs: mkfs.c
	gcc -Werror -Wall -I. -o $@ $^

%.o: %.c
	$(ARMGNU)-gcc $(COPS) -MMD -c $< -o $@

%_s.o: %.S
	$(ARMGNU)-gcc $(ASMOPS) -MMD -c $< -o $@

build/nes: 
	cd LiteNES && $(MAKE)
	cp LiteNES/nes build/

# to prevent makefile from its implicit rule which is shorter & preferred
# https://www.gnu.org/software/make/manual/html_node/Canceling-Rules.html
% : %.c

#%.elf: %.o $(ULIB)
build/%: %.o $(ULIB)		
	@mkdir -p build
	$(ARMGNU)-ld $(LDFLAGS) -T user.ld -o $@ $^
	@$(ARMGNU)-objdump -S $@ > $*.asm
	@$(ARMGNU)-objdump -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $*.sym

clean: 
	rm -f *.o $(UPROGS) mkfs *.d *.sym *.asm sd.bin