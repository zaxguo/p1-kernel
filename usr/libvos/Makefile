# libos: our kernel's glue for libc (newlib)
# needed for any user apps that depend on libc

include $(abspath ../../config.mk)

TARGETLIB = libvos.a
OBJS = syscall.o usys_s.o io.o

CFLAGS = -MMD -Wall -Werror -g -fno-omit-frame-pointer
CFLAGS += -nostdinc -nostdlib -nostartfiles -ffreestanding -mgeneral-regs-only
CFLAGS += -Os
CFLAGS += -I $(VOS_REPO_PATH)
CFLAGS += -I $(LIBC_INC_PATH)
# gcc specific 
CFLAGS += -I /usr/lib/gcc-cross/aarch64-linux-gnu/9/include/

ASMOPS += -I $(VOS_REPO_PATH)

include $(abspath ../librules.mk)

%.o: %.c 
	@echo  USER CC $< "->" $@
	@$(CC) $(CFLAGS) -MMD -c $< -o $@

%_s.o: %.S
	@echo  USER AS $< "->" $@
	@$(CC) $(ASMOPS) -MMD -c $< -o $@

clean: 
	rm -f *.o *.a *.d *.sym *.asm