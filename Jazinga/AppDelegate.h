//
//  AppDelegate.h
//
//  Created by John Mah on 12-05-10.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JazingaLoginDelegate.h"
#import "SIPAccountManager.h"
#import "SIPCallDetails.h"
#import "Call.h"
#import "Reachability.h"

typedef struct tonegen_data
{
    pj_pool_t          *pool;
    pjmedia_port       *tonegen;
    pjsua_conf_port_id  toneslot;
} tonegen_data;

#define USE_TCP_TRANSPORT 1

#ifdef USE_TCP_TRANSPORT
#define TCP_APPENDER    @";transport=TCP"
#else
#define TCP_APPENDER    @""
#endif

extern NSString *const kExtensionsChangedNotification;

@interface AppDelegate : UIResponder <UIApplicationDelegate> {
    
}

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (strong, nonatomic) Reachability *internetReach;
@property tonegen_data *dialer_data;
@property (strong,nonatomic) SIPAccountManager *accountsManager;
@property (strong,nonatomic) NSTimer *vibrationTimer;
@property (strong,nonatomic) NSMutableDictionary *pendingNotifications;
@property (strong,nonatomic) NSArray *extensions;
@property (strong,nonatomic) NSArray *teams;
@property (strong,nonatomic) NSArray *apps;

+ (AppDelegate*)sharedAppDelegate;

- (BOOL)calls_in_progress;
- (void)answer_call:(pjsua_call_id)call_id;
- (void)decline_call:(pjsua_call_id)call_id;
- (void)call:(NSString*)name withNumber:(NSString*)phoneNumber;
- (void)call:(NSString*)name withSipUrl:(NSString*)url;
- (void)recordGreeting:(NSString*)greeting caption:(NSString*)caption;

- (void)present:(pjsua_call_id)call_id;
- (void)cancel:(pjsua_call_id)call_id;
- (void)active:(pjsua_call_id)call_id;
- (void)hold:(pjsua_call_id)call_id;
- (void)transfer:(pjsua_call_id)call_id number:(NSString*)phoneNumber;
- (void)add:(pjsua_call_id)call_id number:(NSString*)phoneNumber;

- (tonegen_data*)dialer_tonegen;

- (void)send:(pjsua_call_id)call_id digit:(unichar)digit duration:(NSTimeInterval)duration;
- (void)stop_dtmf:(pjsua_call_id)call_id digit:(unichar)digit;

- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;

- (void)addCallLogEntry:(SIPCallDetails*)callDetails
                  start:(NSDate*)start 
                    end:(NSDate*)end;
- (void)showAlert:(NSString*)title 
      withMessage:(NSString*)message;

- (void)startVibrate;
- (void)stopVibrate;
- (void)vibrate;

- (NSArray*)extensions;
- (NSArray*)teams;
- (NSArray*)apps;

@end
