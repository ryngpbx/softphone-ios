//
//  SIPAudioManager.m
//  Jazinga
//
//  Created by John Mah on 2013-01-23.
//  Copyright (c) 2013 Jazinga Inc. All rights reserved.
//

#import "SIPAudioManager.h"
#if !TARGET_OS_IPHONE
#import <CoreAudio/CoreAudio.h>
#else
#import <AudioToolbox/AudioToolbox.h>
#endif
#import <pjsua-lib/pjsua.h>
#import <pj/types.h>

SIPAudioManager* sharedAudioManager = nil;
pj_thread_t *audio_thread = NULL;
pj_thread_desc audio_thread_desc;

@implementation SIPAudioManager

+ (SIPAudioManager*)sharedSIPAudioManager
{
	@autoreleasepool {
		if (sharedAudioManager == nil) {
			sharedAudioManager = [[SIPAudioManager alloc] init];
		}
		return sharedAudioManager;
	}
}

- (id)init
{
	self = [super init];
	if (self) {
		// build list of devices
		[self refreshDeviceList];

		// This is a largely undocumented but absolutely necessary
		// requirement starting with OS-X 10.6.  If not called, queries and
		// updates to various audio device properties are not handled
		// correctly.
#if !TARGET_OS_IPHONE
		CFRunLoopRef theRunLoop = CFRunLoopGetMain();
		AudioObjectPropertyAddress property = { kAudioHardwarePropertyRunLoop,
			kAudioObjectPropertyScopeGlobal,
			kAudioObjectPropertyElementMaster };
		OSStatus result = AudioObjectSetPropertyData(kAudioObjectSystemObject,
													 &property, 0, NULL, sizeof(CFRunLoopRef),
													 &theRunLoop);
		
		// install kAudioHardwarePropertyDevices notification listener
		AudioObjectPropertyAddress theAddress = { kAudioHardwarePropertyDevices,
			kAudioObjectPropertyScopeGlobal,
			kAudioObjectPropertyElementMaster };
		
		AudioObjectAddPropertyListener(kAudioObjectSystemObject, &theAddress,
									   AOPropertyListenerProc, (__bridge void*)self);
#endif /* !TARGET_OS_IPHONE */
	}
	return self;
}

- (void)dealloc
{
#if !TARGET_OS_IPHONE
	// remove kAudioHardwarePropertyDevices notification listener
    AudioObjectPropertyAddress theAddress = { kAudioHardwarePropertyDevices,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMaster };
    
    AudioObjectRemovePropertyListener(kAudioObjectSystemObject, &theAddress, AOPropertyListenerProc, (__bridge void*)self);
#endif /* !TARGET_OS_IPHONE */
}

- (void)refreshDeviceList
{
	self.inputDevices = [self enumerateInputDevices];
	self.outputDevices = [self enumerateOutputDevices];
	
	// this makes sure the change notification happens on the MAIN THREAD
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kSIPAudioDeviceListChanged
                                                            object:self];
    });
}

- (NSArray*)enumerateInputDevices
{
	int AUD_DEV_MAX = 10;
	unsigned count = AUD_DEV_MAX;
	pjmedia_aud_dev_info info[AUD_DEV_MAX];
	pj_status_t status = pjsua_enum_aud_devs(info, &count);
	if (status != PJ_SUCCESS) return nil;
	
	NSMutableArray *inputDevices = [[NSMutableArray alloc] init];
	for (int i = 0; i < count; i++) {
		pjmedia_aud_dev_info *next = &info[i];
		const char *name = next->name;
		
		// see if this an input device
		if (next->input_count > 0) {
			[inputDevices addObject:[NSString stringWithCString:name encoding:NSUTF8StringEncoding]];
		}
	}
	
	return [NSArray arrayWithArray:inputDevices];
}

- (NSArray*)enumerateOutputDevices
{
	int AUD_DEV_MAX = 10;
	unsigned count = AUD_DEV_MAX;
	pjmedia_aud_dev_info info[AUD_DEV_MAX];
	pj_status_t status = pjsua_enum_aud_devs(info, &count);
	if (status != PJ_SUCCESS) return nil;

	NSMutableArray *outputDevices = [[NSMutableArray alloc] init];
	for (int i = 0; i < count; i++) {
		pjmedia_aud_dev_info *next = &info[i];
		const char *name = next->name;
		
		// see if this is an output device
		if (next->output_count > 0) {
			[outputDevices addObject:[NSString stringWithCString:name encoding:NSUTF8StringEncoding]];
		}
	}
	
	return [NSArray arrayWithArray:outputDevices];
}

- (void)configureRingingDevice
{
	// select proper input/output device
	const char *drv_name = PJSIP_AUDIO_DRIVER;
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	NSString *ringingDevice = [ud stringForKey:@"default_ringing_device"];
	
	pjmedia_aud_dev_index rdevice;
	pj_status_t status = pjmedia_aud_dev_lookup(drv_name,
												[ringingDevice cStringUsingEncoding:NSUTF8StringEncoding],
												&rdevice);
	
	pjmedia_aud_dev_index idevice;
	pjmedia_aud_dev_index odevice;
	status = pjsua_get_snd_dev(&idevice, &odevice);
	
	// only set the audio device if not on a call
	if (status == PJ_SUCCESS && pjsua_call_get_count() == 0)
		status = pjsua_set_snd_dev(idevice, rdevice);
}

- (void)configureCallAudio
{
	// select proper input/output device
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	NSString *inputDevice = [ud stringForKey:@"default_input_device"];
	NSString *outputDevice = [ud stringForKey:@"default_output_device"];
	
	[self configureCallAudioOutput:outputDevice input:inputDevice];
}

- (void)configureCallAudioOutput:(NSString*)outputDevice input:(NSString*)inputDevice
{
	// select proper input/output device
	const char *drv_name = PJSIP_AUDIO_DRIVER;
	
	pjmedia_aud_dev_index idevice, odevice;
	pj_status_t status = pjmedia_aud_dev_lookup(drv_name,
												[inputDevice cStringUsingEncoding:NSUTF8StringEncoding], &idevice);
	if (status != PJ_SUCCESS)
		idevice = PJMEDIA_AUD_DEFAULT_CAPTURE_DEV;
	
	status = pjmedia_aud_dev_lookup(drv_name,
									[outputDevice cStringUsingEncoding:NSUTF8StringEncoding], &odevice);
	if (status != PJ_SUCCESS)
		odevice = PJMEDIA_AUD_DEFAULT_PLAYBACK_DEV;
	
	[self dumpAudioDriverInfo];

	// only set the audio devices if on a call
	if (status == PJ_SUCCESS && pjsua_call_get_count() > 0) {
		status = pjsua_set_snd_dev(idevice, odevice);
	}
}

- (void)dumpAudioDriverInfo
{
#ifdef DEBUG
	int AUD_DEV_MAX = 10;
	unsigned count = AUD_DEV_MAX;
	pjmedia_aud_dev_info info[AUD_DEV_MAX];
	pj_status_t status = pjsua_enum_aud_devs(info, &count);
	if (status != PJ_SUCCESS) return;
	
	for (int i = 0; i < count; i++) {
		pjmedia_aud_dev_info *next = &info[i];
		
		pjmedia_aud_dev_index device;
		pjmedia_aud_dev_lookup(next->driver, next->name, &device);
		NSLog(@"audio device: (driver=%s, device=%s, dev_id=%ud",
			  next->driver, next->name, device);
	}
	
	return;	
#endif
}

- (void)refresh
{
	// set no audio devices while refreshing -- prevents crash in pjmedia_aud_dev_refresh()
	pjsua_set_no_snd_dev();
	
	// refresh audio device list and recache the info
	pjmedia_aud_dev_refresh();
	[self refreshDeviceList];
	
	// chances are the old device indexes are junk now, so use last settings
	if (pjsua_call_get_count() > 0) {
		[self configureCallAudio];
	} else {
		[self configureRingingDevice];
	}
}

#if TARGET_OS_IPHONE

- (NSArray*)bluetoothDevices
{
    // check if bluetooth is available
	CFArrayRef inputSources = NULL;
	OSStatus s = AudioSessionSetProperty(kAudioSession_AudioRouteKey_Inputs,
										 sizeof(inputSources),
										 &inputSources
										 );
	return (__bridge_transfer NSArray*)inputSources;
}

- (BOOL)bluetoothAvailable
{
    // check if bluetooth is available
	UInt32 allowBluetoothInput = 1;
	OSStatus s = AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryEnableBluetoothInput,
										 sizeof(allowBluetoothInput),
										 &allowBluetoothInput
										 );
	NSLog(@"status = %x", s);    // problem if this is not zero
	
	// check the audio route
	UInt32 size = sizeof(CFStringRef);
	CFStringRef route;
	OSStatus result = AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &size, &route);
	NSLog(@"route = %@", route);
	
	NSString *audioRoute = (__bridge_transfer NSString*)route;
    return ([audioRoute compare:@"HeadsetBT"] == NSOrderedSame);
}

#endif /* TARGET_OS_IPHONE */

#if !TARGET_OS_IPHONE
OSStatus AOPropertyListenerProc(AudioObjectID inObjectID, UInt32 inNumberAddresses, const AudioObjectPropertyAddress inAddresses[], void* inClientData)
{
    SIPAudioManager *audioManager = (__bridge SIPAudioManager*)inClientData;
    
    for (UInt32 x=0; x<inNumberAddresses; x++) {
        switch (inAddresses[x].mSelector) {
            case kAudioHardwarePropertyDevices:
            {
                fprintf(stderr, "AOPropertyListenerProc: kAudioHardwarePropertyDevices\n");
				[audioManager refresh];
				break;
            }
                
            default:
                fprintf(stderr, "AOPropertyListenerProc: unknown message\n");
				break;
        }
    }
    
    return noErr;
}
#endif /* !TARGET_OS_IPHONE */

@end
