//
//  SIPAccountManager.h
//  Jazinga
//
//  Created by John Mah on 12-07-27.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <pjlib.h>
#import <pjsua.h>
#include <pjsua-lib/pjsua.h>
#include "pjsua_app.h"
#include <pj/types.h>
#import "Reachability.h"
#import "JazingaLoginDelegate.h"

extern NSString *const kSIPRegistrationChangedNotification;

@interface SIPAccountManager : NSObject

@property (strong,nonatomic,setter = setLocalAccount:) NSMutableDictionary *localAccount;
@property (strong,nonatomic,setter = setRemoteAccount:) NSMutableDictionary *remoteAccount;
@property (strong,nonatomic) NSMutableDictionary *active;
@property (strong,nonatomic) Reachability *localReach;
@property (strong,nonatomic) Reachability *remoteReach;
@property (strong,nonatomic) Reachability *reach;
@property BOOL forceRemote;
@property (strong,nonatomic) id<JazingaLoginDelegate> loginDelegate;

+ (SIPAccountManager*)sharedAccountManager;
+ (NSMutableDictionary*)createAccountInfo:(NSString*)sipURI;
+ (NSMutableDictionary*)createStaticAccountInfo:(NSString*)username
                                       password:(NSString*)password
                                           host:(NSString*)host
                                           port:(NSString*)port
                                         useTCP:(BOOL)useTCP;

- (void)authenticateUser:(NSString*)user
            withPassword:(NSString*)password
                delegate:(id<JazingaLoginDelegate>)delegate;
- (void)logout;
- (BOOL)isLoggedIn;

- (void)registerAccounts;
- (pjsua_acc_id)activeAccount;

- (BOOL)useReachableHost;

- (void)activeFailedRegistration:(pjsua_acc_id)acc_id;
- (void)activeSuccessfulRegistration:(pjsua_acc_id)acc_id;

- (BOOL)hasValidRegistration;

- (void)killRegistration:(pjsua_acc_id)acc_id;
- (void)killAllRegistrations;
- (void)reset;

- (void)keepAlive:(int)timeout;
- (void)startBackgroundOperations;
- (void)finishedBackgroundOperations;

@end
