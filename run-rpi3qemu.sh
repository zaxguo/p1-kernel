# cf for rpi3 qemu: 
#  https://github.com/RT-Thread/rt-thread/blob/master/bsp/raspberry-pi/raspi3-64/qemu-64.sh
#  -sd sd.bin

# hw devices implemented
# https://www.qemu.org/docs/master/system/arm/raspi.html

# qemu v5.2, currently used by 4414
# QEMU=/cs4414-shared/qemu/aarch64-softmmu/qemu-system-aarch64 \
# ${QEMU} -M raspi3 \
# -kernel ./kernel8.img -serial null -serial mon:stdio -nographic \
# -d int -D qemu.log 

# qemu v8, console only
# QEMU=/u/xl6yq/teaching/p1-kernel-workspace/qemu-8.2-apr2024/build/qemu-system-aarch64
# ${QEMU} -M raspi3b \
# -kernel ./kernel8.img -serial null -serial mon:stdio -nographic \
# -d int -D qemu.log 

# qemu v8, grahpics (as referenec)
QEMU=/u/xl6yq/teaching/p1-kernel-workspace/qemu-8.2-apr2024/build/qemu-system-aarch64
${QEMU} -M raspi3b \
-kernel ./kernel8.img -serial null -serial mon:stdio \
-d int -D qemu.log \
-usb -device usb-kbd

# -nographic \


# monitor
# QEMU=/u/xl6yq/teaching/p1-kernel-workspace/qemu-8.2-apr2024/build/qemu-system-aarch64
# ${QEMU} -M raspi3b \
# -kernel ./kernel8.img -monitor stdio -serial null \
# -d int -D qemu.log \
# -nographic \
# -usb -device usb-kbd