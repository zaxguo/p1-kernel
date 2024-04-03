CC      := aarch64-linux-gnu-gcc
CFLAGS  := -MMD -Wall -Werror -nostdlib -g -O2 -fno-omit-frame-pointer
CFLAGS  += -nostartfiles -ffreestanding -mgeneral-regs-only

LDFLAGS := 

CFILES  := $(shell find . -name "*.c")
OBJS    := $(CFILES:%.c=%.o)
OBJS	+= ../ulib.o ../printf.o ../usys_s.o ../umalloc.o ../tinyprintf.o

%.o: %.c
	@echo + CC $< "->" $@
	@$(CC) $(CFLAGS) -c -o $@ $<
 
litenes: $(OBJS)
	@echo + LD "->" $@
	aarch64-linux-gnu-ld $(LDFLAGS) -T ../user.ld -o $@ $^

# $(CC) $(OBJS) $(LDFLAGS) -o litenes

-include $(patsubst %.o, %.d, $(OBJS))

.PHONY: clean

clean:
	rm -rf litenes *.o *.d
