p1-gen-hash-ports() {
    export MYGDBPORT=`echo -n ${USER} | md5sum | cut -c1-8 | printf "%d\n" 0x$(cat -) | awk '{printf "%.0f\n", 50000 + (($1 / 0xffffffff) * 10000)}'`
    echo "set gdb port: ${MYGDBPORT}"
}

p1-gen-hash-ports

echo "Listen at port: ${MYGDBPORT}"
echo "**To terminate QEMU, press Ctrl-a then x"
echo 
echo "  Next: in a separate window, launch gdb: "
echo "      gdb-multiarch build/kernel8.elf "
echo 
echo "  Example gdb commands -- "
echo "      (gdb) file kernel/build/kernel8.elf"
echo "      (gdb) target remote :${MYGDBPORT}"
echo "      (gdb) layout asm"
echo "  You may want to have a custom ~/.gdbinit "
echo "	Details: https://fxlin.github.io/p1-kernel/gdb/"
echo " ------------------------------------------------"

# /cs4414-shared/qemu/aarch64-softmmu/qemu-system-aarch64 -M raspi3 \
# -kernel ./kernel8-rpi3qemu.img -serial null -serial mon:stdio -nographic -gdb tcp::${MYGDBPORT} -S

# qemu v5.2, currently used by 4414
QEMU5=/cs4414-shared/qemu/aarch64-softmmu/qemu-system-aarch64 \

QEMU6=qemu-system-aarch64

# qemu8, apr 2024
QEMU8=/u/xl6yq/teaching/p1-kernel-workspace/qemu-8.2-apr2024/build/qemu-system-aarch64

QEMU=${QEMU6}

KERNEL=./kernel/kernel8-rpi3qemu.img

# qemu, grahpics
qemu_full() {
    ${QEMU} -M raspi3b \
    -kernel ${KERNEL} -serial null -serial mon:stdio \
    -d int -D qemu.log \
    -nographic \
    -usb -device usb-kbd \
    -drive file=smallfat.bin,if=sd,format=raw \
    -gdb tcp::${MYGDBPORT} -S
}

# qemu, no grahpics, no kb, with sd
qemu_small() {
    ${QEMU} -M raspi3b \
    -kernel ${KERNEL} -serial null -serial mon:stdio \
    -d int -D qemu.log \
    -nographic \
    -drive file=smallfat.bin,if=sd,format=raw \
    -gdb tcp::${MYGDBPORT} -S
}

qemu_min () {
    ${QEMU} -M raspi3b \
    -kernel ${KERNEL} -serial null -serial mon:stdio -nographic \
    -d int -D qemu.log \
    -gdb tcp::${MYGDBPORT} -S
}

if [ "$1" = "min" ]
then
    qemu_min
elif [ "$1" = "full" ]
then
    qemu_full
else
    qemu_small
fi