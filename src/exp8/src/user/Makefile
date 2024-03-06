ARMGNU ?= aarch64-linux-gnu

ULIB = ulib.o printf.o usys_s.o

UPROGS = \
	echo.elf ls.elf

sd.bin: $(UPROGS) mkfs
	./mkfs sd.bin $(UPROGS)

COPS = -Wall -Werror -nostdlib -g -O0 -fno-omit-frame-pointer
COPS += -nostartfiles -ffreestanding -mgeneral-regs-only

mkfs: mkfs.c
	gcc -Werror -Wall -I. -o $@ $^

%.o: %.c
	$(ARMGNU)-gcc $(COPS) -MMD -c $< -o $@

%_s.o: %.S
	$(ARMGNU)-gcc $(ASMOPS) -MMD -c $< -o $@

%.elf: %.o $(ULIB)
#_%: %.o $(ULIB)		# not working??
	$(ARMGNU)-ld $(LDFLAGS) -T user.ld -o $@ $^
	$(ARMGNU)-objdump -S $@ > $*.asm
	$(ARMGNU)-objdump -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $*.sym

clean: 
	rm -f *.o $(UPROGS) mkfs *.d *.sym *.asm sd.bin