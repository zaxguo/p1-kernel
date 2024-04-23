include $(abspath ../../config.mk)

# newlib glue 
ULIBNEW = syscall-newlib.o usys-newlib_s.o

# for syscall-newlib.c 
CNEWOPS = -MMD -Wall -Werror -g -fno-omit-frame-pointer
CNEWOPS += -nostdinc -nostdlib -nostartfiles -ffreestanding -mgeneral-regs-only
CNEWOPS += -Os
CNEWOPS += -I $(VOS_REPO_PATH)
CNEWOPS += -I $(NEWLIB_INC_PATH)
# gcc specific 
CNEWOPS += -I /usr/lib/gcc-cross/aarch64-linux-gnu/9/include/

ASMOPS += -I $(VOS_REPO_PATH)

libnew.a: $(ULIBNEW)
	@rm -f $@
	ar rc $@ $(ULIBNEW)
	ranlib $@

%.o: %.c 
	$(ARMGNU)-gcc-9 $(CNEWOPS) -MMD -c $< -o $@

%_s.o: %.S
	@echo  USER AS $< "->" $@
	@$(ARMGNU)-gcc-9 $(ASMOPS) -MMD -c $< -o $@

clean: 
	rm -f *.o *.a *.d *.sym *.asm