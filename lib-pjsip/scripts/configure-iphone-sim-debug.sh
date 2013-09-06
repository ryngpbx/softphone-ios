export DEVPATH="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer"
export CC="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/usr/bin/llvm-gcc"
export ARCH="-arch i386"
export CFLAGS="-g -m32 -miphoneos-version-min=4.0"
export LDFLAGS="-m32"
./configure-iphone
make dep && make clean && make

