#PLAT ?= virt
PLAT ?= rpi3qemu

ARMGNU ?= aarch64-linux-gnu
COPS = -Wall -Werror -nostdlib -nostartfiles -ffreestanding -Isrc \
-mgeneral-regs-only \
-g 

COPS += -DCONFIG_KAGE_GLOBAL_DEBUG_LEVEL=10   # verbose
# COPS += -DUSE_LFB		# uncomment this to enable GUI console. 

ASMOPS = -Isrc  -g 

##### platform specific flags ########
ifeq (${PLAT}, virt)
COPS += -DPLAT_VIRT
ASMOPS += -DPLAT_VIRT
LINKSCR = $(SRC_DIR)/linker-virt.ld
endif

ifeq (${PLAT}, rpi3qemu)
COPS += -DPLAT_RPI3QEMU
ASMOPS += -DPLAT_RPI3QEMU
LINKSCR = $(SRC_DIR)/linker-rpi3qemu.ld
endif
#################################

##### the flags for certain .c files that must use -O0
COPS1 = $(COPS)
COPS1 += -O0
#COPS += -O2
COPS += -O0

BUILD_DIR = build
SRC_DIR = src

all : kernel8.img 

clean :
	rm -rf $(BUILD_DIR) *.img 

# use -O0 only for user.c (launcher), for which -O2 emits references to kernel va and crashes things
$(BUILD_DIR)/user_c.o: $(SRC_DIR)/user.c
	mkdir -p $(@D)
	$(ARMGNU)-gcc $(COPS1) -MMD -c $< -o $@

$(BUILD_DIR)/%_c.o: $(SRC_DIR)/%.c
	mkdir -p $(@D)
	$(ARMGNU)-gcc $(COPS) -MMD -c $< -o $@

# font build rules. 
# NB: the symbols in the binary will have prefix "_binary". 
$(BUILD_DIR)/%_psf.o: %.psf
	mkdir -p $(@D)
	$(ARMGNU)-ld -r -b binary -o $@ $<

# ramdisk build rules
$(BUILD_DIR)/%_bin.o: %.bin
	mkdir -p $(@D)
	$(ARMGNU)-ld -r -b binary -o $@ $<

# asm rule 
$(BUILD_DIR)/%_s.o: $(SRC_DIR)/%.S
	$(ARMGNU)-gcc $(ASMOPS) -MMD -c $< -o $@

# generic kernel
C_OBJS = $(BUILD_DIR)/bio_c.o
C_OBJS += $(BUILD_DIR)/console_c.o
C_OBJS += $(BUILD_DIR)/exec_c.o
C_OBJS += $(BUILD_DIR)/file_c.o
C_OBJS += $(BUILD_DIR)/fork_c.o
C_OBJS += $(BUILD_DIR)/fs_c.o
C_OBJS += $(BUILD_DIR)/gic_c.o
C_OBJS += $(BUILD_DIR)/irq_c.o
C_OBJS += $(BUILD_DIR)/kernel_c.o
C_OBJS += $(BUILD_DIR)/lfb_c.o
C_OBJS += $(BUILD_DIR)/log_c.o
C_OBJS += $(BUILD_DIR)/mm_c.o
C_OBJS += $(BUILD_DIR)/pipe_c.o
C_OBJS += $(BUILD_DIR)/printf_c.o
C_OBJS += $(BUILD_DIR)/ramdisk_c.o
C_OBJS += $(BUILD_DIR)/sched_c.o
C_OBJS += $(BUILD_DIR)/sleeplock_c.o
C_OBJS += $(BUILD_DIR)/spinlock_c.o
C_OBJS += $(BUILD_DIR)/string_c.o
C_OBJS += $(BUILD_DIR)/sys_c.o
C_OBJS += $(BUILD_DIR)/sysfile_c.o
C_OBJS += $(BUILD_DIR)/timer_c.o
C_OBJS += $(BUILD_DIR)/user_c.o
C_OBJS += $(BUILD_DIR)/mbox_c.o

ASM_OBJS = $(BUILD_DIR)/boot_s.o
ASM_OBJS += $(BUILD_DIR)/entry_s.o
ASM_OBJS += $(BUILD_DIR)/sched_s.o
ASM_OBJS += $(BUILD_DIR)/user_sys_s.o
ASM_OBJS += $(BUILD_DIR)/utils_s.o

# ramdisk image
BIN_OBJS = $(BUILD_DIR)/sd_bin.o
BIN_OBJS += $(BUILD_DIR)/font_psf.o

# plat specific source 
ifeq (${PLAT}, rpi3qemu)
C_OBJS += $(BUILD_DIR)/mini_uart_c.o
endif

ifeq (${PLAT}, virt)
C_OBJS += $(BUILD_DIR)/pl011_c.o
C_OBJS += $(BUILD_DIR)/virtio_disk_c.o
endif

DEP_FILES = $(C_OBJS:%.o=%.d)
-include $(DEP_FILES)

kernel8.img: $(LINKSCR) $(C_OBJS) $(ASM_OBJS) $(BIN_OBJS)
	$(ARMGNU)-ld -T $(LINKSCR) -o $(BUILD_DIR)/kernel8.elf $(C_OBJS) $(ASM_OBJS) $(BIN_OBJS)
	$(ARMGNU)-objcopy $(BUILD_DIR)/kernel8.elf -O binary kernel8.img
	$(ARMGNU)-objdump -dS $(BUILD_DIR)/kernel8.elf > kernel8.asm
	nm --numeric-sort $(BUILD_DIR)/kernel8.elf > kernel8.sym
