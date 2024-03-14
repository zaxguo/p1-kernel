ARMGNU ?= aarch64-linux-gnu

COPS = -Wall -Werror -nostdlib -nostartfiles -ffreestanding -Isrc -mgeneral-regs-only \
-g -DUSE_QEMU -DPLAT_VIRT
COPS += -O2
# COPS += -O0
COPS += -DCONFIG_KAGE_GLOBAL_DEBUG_LEVEL=10   # verbose

# COPS += -DUSE_LFB		# uncomment this to enable GUI console. 
ASMOPS = -Isrc  -g -DUSE_QEMU \
-DPLAT_VIRT

BUILD_DIR = build
SRC_DIR = src

all : kernel8.img

clean :
	rm -rf $(BUILD_DIR) *.img 

#mkfs: ${SRC_DIR}/mkfs/mkfs
#${SRC_DIR}/mkfs/mkfs: ${SRC_DIR}/mkfs/mkfs.c
#	gcc -Werror -Wall -I. -o $@ $^

# use -O0 only for user.c (launcher), for which -O2 emits references to kernel va and crashes things
COPS1 = -Wall -Werror -nostdlib -nostartfiles -ffreestanding -Isrc -mgeneral-regs-only \
-g -DUSE_QEMU -DPLAT_VIRT
COPS1 += -O0
COPS1 += -DCONFIG_KAGE_GLOBAL_DEBUG_LEVEL=10   # verbose
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

$(BUILD_DIR)/%_s.o: $(SRC_DIR)/%.S
	$(ARMGNU)-gcc $(ASMOPS) -MMD -c $< -o $@

C_FILES = $(wildcard $(SRC_DIR)/*.c)
ASM_FILES = $(wildcard $(SRC_DIR)/*.S)
OBJ_FILES = $(C_FILES:$(SRC_DIR)/%.c=$(BUILD_DIR)/%_c.o)
OBJ_FILES += $(ASM_FILES:$(SRC_DIR)/%.S=$(BUILD_DIR)/%_s.o)
OBJ_FILES += $(BUILD_DIR)/sd_bin.o 		# ramdisk image
OBJ_FILES += $(BUILD_DIR)/font_psf.o


DEP_FILES = $(OBJ_FILES:%.o=%.d)
-include $(DEP_FILES)

kernel8.img: $(SRC_DIR)/linker-qemu.ld $(OBJ_FILES)
	$(ARMGNU)-ld -T $(SRC_DIR)/linker-qemu.ld -o $(BUILD_DIR)/kernel8.elf  $(OBJ_FILES)
	$(ARMGNU)-objcopy $(BUILD_DIR)/kernel8.elf -O binary kernel8.img
	$(ARMGNU)-objdump -dS $(BUILD_DIR)/kernel8.elf > kernel8.asm
	nm --numeric-sort $(BUILD_DIR)/kernel8.elf > kernel8.sym
