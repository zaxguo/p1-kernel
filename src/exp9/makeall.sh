# pushd .
# cd addon/usb/lib
# make clean && make -j20
# popd

pushd .
cd src/usr/
make clean && make PLAT=rpi3qemu -j20
popd

make clean && make PLAT=rpi3qemu -j20
