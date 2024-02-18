/cs4414-shared/qemu/aarch64-softmmu/qemu-system-aarch64 -M virt,gic-version=2 -cpu cortex-a53 -m 128M -smp 4 -kernel ./kernel8.img -serial mon:stdio -nographic
