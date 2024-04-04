CC      := aarch64-linux-gnu-gcc
CFLAGS  := -MMD -Wall -Werror -nostdlib -g -O2 -fno-omit-frame-pointer
CFLAGS  += -nostartfiles -ffreestanding -mgeneral-regs-only

LDFLAGS := 

CFILES  := $(shell find . -name "*.c")
OBJS    := $(CFILES:%.c=%.o)
OBJS	+= ../ulib.o ../printf.o ../usys_s.o ../umalloc.o ../tinyprintf.o
OBJS	+= ../uio.o 

%.o: %.c
	@echo + CC $< "->" $@
	@$(CC) $(CFLAGS) -c -o $@ $<
 
nes: $(OBJS)
	@echo + LD "->" $@
	aarch64-linux-gnu-ld $(LDFLAGS) -T ../user.ld -o $@ $^

# $(CC) $(OBJS) $(LDFLAGS) -o nes

-include $(patsubst %.o, %.d, $(OBJS))

.PHONY: clean

clean:
	rm -rf nes *.o *.d
