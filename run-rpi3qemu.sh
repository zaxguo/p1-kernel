# cf for rpi3 qemu: 
#  https://github.com/RT-Thread/rt-thread/blob/master/bsp/raspberry-pi/raspi3-64/qemu-64.sh
#  -sd sd.bin

# hw devices implemented
# https://www.qemu.org/docs/master/system/arm/raspi.html

# qemu v5.2, currently used by 4414
QEMU5=/cs4414-shared/qemu/aarch64-softmmu/qemu-system-aarch64

# qemu6, deefaul ton Ubuntu 2204
# seems good
QEMU6=qemu-system-aarch64

# qemu8, apr 2024
# good
#QEMU8=/u/xl6yq/teaching/p1-kernel-workspace/qemu-8.2-apr2024/build/qemu-system-aarch64 
# incomplete build under wsl? no graphics?? to fix (Apr 2024)
#QEMU8=~/qemu-8.2-apr2024/build/qemu-system-aarch64   

QEMU=${QEMU6}

KERNEL=./kernel/kernel8-rpi3qemu.img

# ${QEMU} -M raspi3 \
# -kernel ./kernel8-rpi3qemu.img -serial null -serial mon:stdio -nographic \
# -d int -D qemu.log 

#### qemu v8, console only
# ${QEMU} -M raspi3b \
# -kernel ./kernel8-rpi3qemu.img -serial null -serial mon:stdio -nographic \
# -d int -D qemu.log 

### qemu v8, no grahpics, no kb, with sd
# ${QEMU} -M raspi3b \
# -kernel ${KERNEL} -serial null -serial mon:stdio \
# -d int -D qemu.log \
# -nographic \
# -drive file=smallfat.bin,if=sd,format=raw

### qemu v8, + grahpics, + kb, + sdls
${QEMU} -M raspi3b \
-kernel ${KERNEL} -serial null -serial mon:stdio \
-d int -D qemu.log \
-usb -device usb-kbd \
-drive file=smallfat.bin,if=sd,format=raw

# -nographic \

### qemu v8, no gfx, no kb, virtual fat
# cannot make it work as sd driver expects certain
# disk size. cannot fig out how to speicfy 
# ${QEMU8} -M raspi3b \
# -kernel ./kernel8-rpi3qemu.img -serial null -serial mon:stdio \
# -d int -D qemu.log \
# -nographic \
# -drive file=fat:rw:/tmp/testdir,if=sd,format=raw

##### qemuv8 monitor
# ${QEMU8} -M raspi3b \
# -kernel ./kernel8-rpi3qemu.img -monitor stdio -serial null \
# -d int -D qemu.log \
# -nographic \
# -usb -device usb-kbd