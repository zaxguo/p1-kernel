include $(abspath ../../config.mk)

OBJS = video.o keyboard.o event.o timer.o general.o 
OBJS += audio.o

COPS = -MMD -Wall -Werror -g -fno-omit-frame-pointer
COPS += -nostdinc -nostdlib -nostartfiles -ffreestanding
COPS += -Os
COPS += -I include
COPS += -I $(NEWLIB_INC_PATH)
COPS += -I $(LIBNEW_PATH)
# gcc specific 
COPS += -I /usr/lib/gcc-cross/aarch64-linux-gnu/9/include/


libminisdl.a: $(OBJS)
	@rm -f $@
	ar rc $@ $(OBJS)
	ranlib $@

%.o: src/%.c
	@echo  USER CC $< "->" $@
	@$(ARMGNU)-gcc-9 $(COPS) -MMD -c $< -o $@

clean: 
	rm -f *.o $(OBJS) src/*.d *.sym *.asm