#!/bin/sh

ROOT=$(cd $(dirname $0)/; pwd)

# location of PJSIP trunk
PJSIP_IOS=pjsip-ios-iphoneos
PJSIP_SIM=pjsip-ios-iphonesimulator

DESTDIR_IOS=Debug-iphoneos
DESTDIR_SIM=Debug-iphonesimulator
DESTDIR=Debug-iphoneos

echo "Updating code..."
# pull down SVN trunk of PJSIP
if [ -d $PJSIP_IOS ]; then
	echo "Updating pjsip for ios"
	svn update -q http://svn.pjsip.org/repos/pjproject/trunk@4232 $PJSIP_IOS
else
	echo "Checking out pjsip for ios"
	svn co -q http://svn.pjsip.org/repos/pjproject/trunk@4232 $PJSIP_IOS
fi
if [ -d $PJSIP_SIM ]; then
	echo "Updating pjsip for ios simulator"
	svn update -q http://svn.pjsip.org/repos/pjproject/trunk@4232 $PJSIP_SIM
else
	echo "Checking out pjsip for ios simulator"
	svn co -q http://svn.pjsip.org/repos/pjproject/trunk@4232 $PJSIP_SIM
fi

# copy over iPhone config header file
echo "Copying in our configs"
cp config/config_site.h $PJSIP_IOS/pjlib/include/pj/config_site.h
cp config/config_site.h $PJSIP_SIM/pjlib/include/pj/config_site.h

echo "Building iphone"
# Build
cd $ROOT/$PJSIP_IOS
$ROOT/scripts/configure-iphone-debug.sh > log.iphone.txt 2>&1
cd $ROOT

echo "Building simulator"
cd $ROOT/$PJSIP_SIM
$ROOT/scripts/configure-iphone-sim-debug.sh > log.simulator.txt 2>&1
cd $ROOT

echo "Copying files to lib directories"
# Copy all this stuff somewhere else (reason unknown)
cp -Rf $PJSIP_IOS/pjlib $DESTDIR_IOS
cp -Rf $PJSIP_IOS/pjlib-util $DESTDIR_IOS
cp -Rf $PJSIP_IOS/pjmedia $DESTDIR_IOS
cp -Rf $PJSIP_IOS/pjnath $DESTDIR_IOS
cp -Rf $PJSIP_IOS/pjsip $DESTDIR_IOS
cp -Rf $PJSIP_IOS/third_party $DESTDIR_IOS

cp -Rf $PJSIP_SIM/pjlib $DESTDIR_SIM
cp -Rf $PJSIP_SIM/pjlib-util $DESTDIR_SIM
cp -Rf $PJSIP_SIM/pjmedia $DESTDIR_SIM
cp -Rf $PJSIP_SIM/pjnath $DESTDIR_SIM
cp -Rf $PJSIP_SIM/pjsip $DESTDIR_SIM
cp -Rf $PJSIP_SIM/third_party $DESTDIR_SIM
