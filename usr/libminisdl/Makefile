include $(abspath ../../config.mk)

TARGETLIB = libminisdl.a

OBJS = video.o keyboard.o event.o timer.o general.o 
OBJS += audio.o

COPS = -MMD -Wall -Werror -g -fno-omit-frame-pointer
COPS += -nostdinc -nostdlib -nostartfiles -ffreestanding
COPS += -Os
COPS += -I include
COPS += -I $(LIBC_INC_PATH)
COPS += -I $(LIBVOS_PATH)
# gcc specific 
COPS += -I /usr/lib/gcc-cross/aarch64-linux-gnu/9/include/

include $(abspath ../librules.mk)

%.o: src/%.c
	@echo  USER CC $< "->" $@
	@$(CC) $(COPS) -MMD -c $< -o $@

clean: 
	rm -f *.o $(OBJS) src/*.d *.sym *.asm