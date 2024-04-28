# a "bare" user program. no dependency on libc (newlib) 

CC      := aarch64-linux-gnu-gcc-9
CFLAGS  := -MMD -Wall -Werror -nostdlib -g -fno-omit-frame-pointer
CFLAGS  += -nostartfiles -ffreestanding -mgeneral-regs-only
CFLAGS  += -O2  # Os to fit xv6 fs limit. should do -O2

LDFLAGS := 

CFILES  := $(shell find . -name "*.c")
OBJS    := $(CFILES:%.c=%.o)
OBJS	+= ../ulib.o ../printf.o ../usys_s.o ../umalloc.o
OBJS	+= ../uio.o ../tinyprintf.o

%.o: %.c
	@echo + CC $< "->" $@
	@$(CC) $(CFLAGS) -c -o $@ $<
 
nes: $(OBJS)
	@echo + LD "->" $@
	@aarch64-linux-gnu-ld $(LDFLAGS) -T nes.ld -o $@ $^

# $(CC) $(OBJS) $(LDFLAGS) -o nes

-include $(patsubst %.o, %.d, $(OBJS))

.PHONY: clean

clean:
	rm -rf nes *.o *.d
