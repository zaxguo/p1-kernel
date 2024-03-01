# only show monitor. used to check qemu memmap, dev tree, etc.

# cf: https://github.com/RT-Thread/rt-thread/blob/master/bsp/qemu-virt64-aarch64/qemu.sh

/cs4414-shared/qemu/aarch64-softmmu/qemu-system-aarch64 -M virt,gic-version=2,virtualization=on \
-cpu cortex-a53 -m 128M -smp 4 -kernel ./kernel8.img -serial null -nographic \
-drive if=none,file=sd.bin,format=raw,id=blk0 -device virtio-blk-device,drive=blk0,bus=virtio-mmio-bus.0 \
-monitor stdio

