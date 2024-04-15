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
echo "      (gdb) file build/kernel8.elf"
echo "      (gdb) target remote :${MYGDBPORT}"
echo "      (gdb) layout asm"
echo "  You may want to have a custom ~/.gdbinit "
echo "	Details: https://fxlin.github.io/p1-kernel/gdb/"
echo " ------------------------------------------------"

# /cs4414-shared/qemu/aarch64-softmmu/qemu-system-aarch64 -M raspi3 \
# -kernel ./kernel8.img -serial null -serial mon:stdio -nographic -gdb tcp::${MYGDBPORT} -S


# qemu v8, grahpics
# QEMU=/u/xl6yq/teaching/p1-kernel-workspace/qemu-8.2-apr2024/build/qemu-system-aarch64
# ${QEMU} -M raspi3b \
# -kernel ./kernel8.img -serial null -serial mon:stdio \
# -d int -D qemu.log \
# -usb -device usb-kbd \
# -gdb tcp::${MYGDBPORT} -S

# qemu v8, no grahpics, no kb, with sd
QEMU=/u/xl6yq/teaching/p1-kernel-workspace/qemu-8.2-apr2024/build/qemu-system-aarch64
${QEMU} -M raspi3b \
-kernel ./kernel8.img -serial null -serial mon:stdio \
-d int -D qemu.log \
-nographic \
-drive file=smallfat.bin,if=sd,format=raw \
-gdb tcp::${MYGDBPORT} -S