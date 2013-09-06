#!/bin/sh

# location of PJSIP trunk
PJSIP=pjsip-ios
DESTDIR=Debug-iphoneos

# pull down SVN trunk of PJSIP
svn co http://svn.pjsip.org/repos/pjproject/trunk $PJSIP

# apply our patches
#patch -p0 -d $PJSIP <patch.jazinga.softphone.diff
#patch -p0 -d $PJSIP <patch.coreaudio.diff

# copy over iPhone config header file
cp config/config_site.h $PJSIP/pjlib/include/pj/config_site.h

# copy over utility scripts
cp scripts/* $PJSIP
