/cs4414-shared/qemu/aarch64-softmmu/qemu-system-aarch64 -M raspi3 \
-kernel ./kernel8.img -serial null -serial mon:stdio -nographic \
-d int -D qemu.log 