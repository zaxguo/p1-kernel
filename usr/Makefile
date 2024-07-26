# xzl Apr 2024 mandates using gcc-9 (not gcc 11 which is default in Ubuntu 22.04)
include $(abspath ../config.mk)

# xv6 userspace lib, minimalist, no dep on libc
ULIB = ulib.o printf.o usys_s.o umalloc.o tinyprintf.o uio.o

# xv6 user programs only dep on ULIB above, no libc, etc
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
	build/wc

# below: UI apps with low dependency 
UPROGS += build/slider
UPROGS += build/buzz
UPROGS += build/nes
# below: UI apps with rich dependency (libc, sdl, & etc
UPROGS += build/nplayer
UPROGS += build/sysmon
UPROGS += build/nes1
# below: cpp, depends on libc
UPROGS += build/blockchain

COPS = -MMD -Wall -Werror -nostdlib -g -fno-omit-frame-pointer
COPS += -nostartfiles -ffreestanding -mgeneral-regs-only
COPS += -O0

ASMOPS = -g

.PRECIOUS: $(ULIB)

all: sd.bin

sd.bin: $(UPROGS) mkfs
	$(VB) rm -f sd.bin
	$(VB) cp logo-uva.txt build/logo.txt
	$(VB) cd build && ../mkfs ../sd.bin `ls` || (echo "sd.bin FAILED"; rm -f ../sd.bin; exit 1)

ulib.a: $(ULIB)
	$(VB) rm -f $@
	$(VB) ar rc $@ $(ULIB)
	$(VB) ranlib $@

mkfs: mkfs.c
	$(VB) gcc -Werror -Wall -I. -o $@ $^

%.o: %.c
	$(VB) echo  USER CC $< "->" $@
	$(VB) $(CC) $(COPS) -MMD -c $< -o $@

%_s.o: %.S
	$(VB) echo  USER AS $< "->" $@
	$(VB) $(CC) $(ASMOPS) -MMD -c $< -o $@

##################
# apps that have their own source dirs
# TODO complete lib dependency
build/nplayer: build-lib/libvos.a build-lib/libminisdl.a build-lib/libvorbis.a
	cd nplayer && $(MAKE)
	cp nplayer/nplayer build/
	$(ARMGNU)-strip build/nplayer

build/sysmon: build-lib/libvos.a build-lib/libminisdl.a
	cd sysmon && $(MAKE)
	cp sysmon/sysmon build/
	$(ARMGNU)-strip build/sysmon
	
# TODO complete lib dependency
build/blockchain:
	cd blockchain && $(MAKE)
	cp blockchain/blockchain build/
	$(ARMGNU)-strip build/blockchain

build/nes: ulib.o printf.o usys_s.o umalloc.o uio.o tinyprintf.o
	cd LiteNES && $(MAKE)
	cp LiteNES/nes build/
	$(ARMGNU)-strip build/nes

build/nes1: build-lib/libvos.a build-lib/libminisdl.a
	cd LiteNES && $(MAKE) -f Makefile.sdl
	cp LiteNES/nes1 build/
	$(ARMGNU)-strip build/nes1

# to prevent makefile from its implicit rule which is shorter & preferred
# https://www.gnu.org/software/make/manual/html_node/Canceling-Rules.html
% : %.c

##################
# user libs 
build-lib/libvos.a:
	cd libvos && $(MAKE) install

build-lib/libvorbis.a:
	cd libvorbis && $(MAKE) install 

build-lib/libminisdl.a:
	cd libminisdl && $(MAKE) install 

######################
#  "lean" user apps, simple rule for building
build/%: %.o ulib.a
	$(VB) echo  USER LD $< "->" $@
	$(VB) mkdir -p build
	$(VB) $(ARMGNU)-ld $(LDFLAGS) -T user.ld -o $@ $^
	$(VB) $(ARMGNU)-objdump -S $@ > $*.asm
	$(VB) $(ARMGNU)-objdump -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $*.sym

clean: 
	rm -f *.o $(UPROGS) build-lib/*.a build-lib/*.o mkfs *.d *.sym *.asm sd.bin