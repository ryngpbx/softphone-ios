#!/usr/bin/env make

# location of PJSIP trunk
PJSIP_IOS=pjsip-ios-iphoneos
PJSIP_SIM=pjsip-ios-iphonesimulator

DESTDIR_IOS=Debug-iphoneos
DESTDIR_SIM=Debug-iphonesimulator

VERSION ?= #4232
#REPOSITORY ?= http://svn.pjsip.org/repos/pjproject/trunk
REPOSITORY ?= http://svn.pjsip.org/repos/pjproject/tags/2.1

all: install-stamp

source-stamp:
	svn co -q $(REPOSITORY)@$(VERSION) $(PJSIP_IOS)
	cp -a $(PJSIP_IOS) $(PJSIP_SIM)
	touch $@

config_site-stamp: source-stamp
	-echo "Copying in our configs"
	cp config/config_site.h $(PJSIP_IOS)/pjlib/include/pj/config_site.h
	cp config/config_site.h $(PJSIP_SIM)/pjlib/include/pj/config_site.h
	touch $@

build-stamp: config_site-stamp
	-echo "Building iphone"
	cd $(PJSIP_IOS); ../scripts/configure-iphone-debug.sh > log.iphone.txt 2>&1

	-echo "Building simulator"
	cd $(PJSIP_SIM); ../scripts/configure-iphone-sim-debug.sh > log.simulator.txt 2>&1
	touch $@

install-stamp: build-stamp
	-echo "Copying files to lib directories"
	# Copy all this stuff somewhere else (reason unknown)
	cp -Rf $(PJSIP_IOS)/pjlib $(DESTDIR_IOS)
	cp -Rf $(PJSIP_IOS)/pjlib-util $(DESTDIR_IOS)
	cp -Rf $(PJSIP_IOS)/pjmedia $(DESTDIR_IOS)
	cp -Rf $(PJSIP_IOS)/pjnath $(DESTDIR_IOS)
	cp -Rf $(PJSIP_IOS)/pjsip $(DESTDIR_IOS)
	cp -Rf $(PJSIP_IOS)/third_party $(DESTDIR_IOS)

	cp -Rf $(PJSIP_SIM)/pjlib $(DESTDIR_SIM)
	cp -Rf $(PJSIP_SIM)/pjlib-util $(DESTDIR_SIM)
	cp -Rf $(PJSIP_SIM)/pjmedia $(DESTDIR_SIM)
	cp -Rf $(PJSIP_SIM)/pjnath $(DESTDIR_SIM)
	cp -Rf $(PJSIP_SIM)/pjsip $(DESTDIR_SIM)
	cp -Rf $(PJSIP_SIM)/third_party $(DESTDIR_SIM)
	touch $@

clean:
	rm -f *-stamp
	rm -rf $(PJSIP_IOS)
	rm -rf $(PJSIP_SIM)
	rm -rf $(DESTDIR_IOS)
	rm -rf $(DESTDIR_SIM)
