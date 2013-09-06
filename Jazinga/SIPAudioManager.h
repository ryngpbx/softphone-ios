//
//  SIPAudioManager.h
//  Jazinga
//
//  Created by John Mah on 2013-01-23.
//  Copyright (c) 2013 Jazinga Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kSIPAudioDeviceListChanged @"kSIPAudioDeviceListChanged"

@interface SIPAudioManager : NSObject

@property (strong,nonatomic) NSArray *inputDevices;
@property (strong,nonatomic) NSArray *outputDevices;

+ (SIPAudioManager*)sharedSIPAudioManager;

- (NSArray*)inputDevices;
- (NSArray*)outputDevices;

- (void)refresh;
- (void)configureRingingDevice;
- (void)configureCallAudio;
- (void)configureCallAudioOutput:(NSString*)outputDevice input:(NSString*)inputDevice;

#if TARGET_OS_IPHONE
- (NSArray*)bluetoothDevices;
- (BOOL)bluetoothAvailable;
#endif

@end
