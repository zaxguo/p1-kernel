# pushd .
# cd addon/usb/lib
# make clean && make -j20
# popd

pushd .
cd usr
make -j10
# make clean && make -j20
popd

pushd .
cd kernel
make -j10
# make clean && make -j20
popd
