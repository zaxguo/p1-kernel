include $(abspath ../../config.mk)

OBJS = stb_vorbis.o

COPS = -MMD -Wall -Werror -g -fno-omit-frame-pointer
COPS += -nostdinc -nostdlib -nostartfiles -ffreestanding
COPS += -O2
COPS += -I include
COPS += -I $(NEWLIB_INC_PATH)
# gcc specific 
COPS += -I /usr/lib/gcc-cross/aarch64-linux-gnu/9/include/

libvorbis.a: $(OBJS)
	@rm -f $@
	ar rc $@ $(OBJS)
	ranlib $@

%.o: %.c
	@echo  USER CC $< "->" $@
	@$(ARMGNU)-gcc-9 $(COPS) -MMD -c $< -o $@

clean: 
	rm -f *.o $(OBJS) *.d *.sym *.asm