#!/bin/sh

# location of PJSIP trunk
PJSIP=pjsip-ios
DESTDIR=Debug-iphoneos

echo PJSIP = $PJSIP
echo DESTDIR = $DESTDIR

# copy build libraries to this location
cp -Rf $PJSIP/pjlib $DESTDIR
cp -Rf $PJSIP/pjlib-util $DESTDIR
cp -Rf $PJSIP/pjmedia $DESTDIR
cp -Rf $PJSIP/pjnath $DESTDIR
cp -Rf $PJSIP/pjsip $DESTDIR
cp -Rf $PJSIP/third_party $DESTDIR

