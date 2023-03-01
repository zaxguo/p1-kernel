# To use: 
#
# xzl@granger1 (master)[p1-kernel]$ source env-qemu.sh
#

export PATH="${HOME}/qemu/aarch64-softmmu:${PATH}"

run-uart0() {
   qemu-system-aarch64 -M raspi3 -kernel ./kernel8.img -serial stdio 
}

run() {
    # xzl the following will launch VNC server w/ binding to a port. in case there are many qemu instancs, it may fail to bind to an addr?
    # qemu-system-aarch64 -M raspi3 -kernel ./kernel8.img -serial null -serial stdio

    # to avoid, launch w/o graphics...
    echo "**Note: use Ctrl-a then x to terminate QEMU"
    qemu-system-aarch64 -M raspi3 -kernel ./kernel8.img -serial null -serial mon:stdio -nographic
}

run-mon() {
    qemu-system-aarch64 -M raspi3 -kernel ./kernel8.img -monitor stdio
}

MYGDBPORT=25678
run-debug() {
    # see comment above 
    # qemu-system-aarch64 -M raspi3 -kernel ./kernel8.img -serial null -serial stdio -s -S

    echo "**Note: use Ctrl-a then x to terminate QEMU"
    echo "	in a separate window, launch gdb: gdb-multiarch build/kernel8.elf"
    echo "	configure gdb by editing ~/.gdbinit "
    echo "	details: https://fxlin.github.io/p1-kernel/gdb/"
    #qemu-system-aarch64 -M raspi3 -kernel ./kernel8.img -serial null -serial mon:stdio -nographic -s -S
    qemu-system-aarch64 -M raspi3 -kernel ./kernel8.img -serial null -serial mon:stdio -nographic -gdb tcp::${MYGDBPORT} -S
}

run-log() {
    qemu-system-aarch64 -M raspi3 -kernel ./kernel8.img -serial null -serial stdio -d int -D qemu.log 
}
