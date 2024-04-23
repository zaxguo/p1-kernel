# xzl Apr 2024 mandates using gcc-9 (not gcc 11 which is default in Ubuntu 22.04)
ARMGNU ?= aarch64-linux-gnu

# xv6 userspace lib, minimalist, no dep on libc
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
	build/buzz	\
	build/nes 

COPS = -MMD -Wall -Werror -nostdlib -g -fno-omit-frame-pointer
COPS += -nostartfiles -ffreestanding -mgeneral-regs-only
COPS += -O0

.PRECIOUS: $(ULIB)

all: sd.bin

sd.bin: $(UPROGS) mkfs
	@rm -f sd.bin
	cd build && ../mkfs ../sd.bin `ls` || (echo "sd.bin FAILED"; rm -f ../sd.bin; exit 1)

ulib.a: $(ULIB)
	@rm -f $@
	ar rc $@ $(ULIB)
	ranlib $@

mkfs: mkfs.c
	gcc -Werror -Wall -I. -o $@ $^

%.o: %.c
	@echo  USER CC $< "->" $@
	@$(ARMGNU)-gcc-9 $(COPS) -MMD -c $< -o $@

%_s.o: %.S
	@echo  USER AS $< "->" $@
	@$(ARMGNU)-gcc-9 $(ASMOPS) -MMD -c $< -o $@

build/nes: ulib.o printf.o usys_s.o umalloc.o uio.o tinyprintf.o
	cd LiteNES && $(MAKE)
	cp LiteNES/nes build/

# to prevent makefile from its implicit rule which is shorter & preferred
# https://www.gnu.org/software/make/manual/html_node/Canceling-Rules.html
% : %.c

#%.elf: %.o $(ULIB)
build/%: %.o ulib.a
	@echo  USER LD $< "->" $@
	@mkdir -p build
	@$(ARMGNU)-ld $(LDFLAGS) -T user.ld -o $@ $^
	@$(ARMGNU)-objdump -S $@ > $*.asm
	@$(ARMGNU)-objdump -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $*.sym

clean: 
	rm -f *.o $(UPROGS) mkfs *.d *.sym *.asm sd.bin