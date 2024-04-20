pushd .
cd addon/usb/lib
make clean
popd

pushd .
cd src/usr/
make clean
popd

make clean
