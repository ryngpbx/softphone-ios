//
//  AppDelegate.m
//
//  Created by John Mah on 12-05-10.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import "AppDelegate.h"
#import "UIDevice+Identifier.h"
#import "NSString+URLEncoding.h"
#import "NSDictionary_JSONExtensions.h"
#import <pjlib.h>
#import <pjsua.h>
#include <pjsua-lib/pjsua.h>
#include "pjsua_app.h"
#include <pj/types.h>
#import "SIPWrapper.h"
#import "JazingaLoginDelegate.h"
#import "PhoneNumber.h"
#import "Call.h"
#import "Contact.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import "InboundViewController.h"

#define THIS_FILE   "AppDelegate.m"

extern struct app_config app_config;
extern pj_log_func *log_cb;

/* Sleep interval duration */
#define SLEEP_INTERVAL	    0.5
/* Print the messages in the debugger console as well */
//#define DEBUGGER_PRINT	    1
/* Whether we should show pj log messages in the text area */
#define SHOW_LOG            1
#define PATH_LENGTH         PJ_MAXPATH
#define PJSIP_THREAD_NAME   "ipjsua"

// 0 == iOS device sound I/O
#define AUDIO_SINK_PORT     0

extern pj_bool_t app_restart;

char argv_buf[PATH_LENGTH];
char *argv[] = {"", "--config-file", argv_buf};

bool app_running;
bool thread_quit;

pj_thread_desc a_thread_desc;
pj_thread_t *a_thread;

pj_status_t jazinga_destroy_pjsip(void);
pj_status_t jazinga_init_pjsip(void);

NSString *const kExtensionsChangedNotification = @"kExtensionsChangedNotification";

static UIBackgroundTaskIdentifier bgBackgroundTask;

void keepAliveFunction(int timeout);

@implementation AppDelegate

@synthesize window = _window;
@synthesize managedObjectContext = __managedObjectContext;
@synthesize managedObjectModel = __managedObjectModel;
@synthesize persistentStoreCoordinator = __persistentStoreCoordinator;
@synthesize internetReach;
@synthesize accountsManager;
@synthesize dialer_data;
@synthesize vibrationTimer;
@synthesize pendingNotifications;
@synthesize extensions;
@synthesize teams;
@synthesize apps;

+ (AppDelegate *)sharedAppDelegate
{
	@autoreleasepool {
		return [UIApplication sharedApplication].delegate;
	}
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	bgBackgroundTask = UIBackgroundTaskInvalid;
	self.pendingNotifications = [[NSMutableDictionary alloc] initWithCapacity:10];
	
    // write default settings on first run in case of fresh installation/re-installation
    NSUserDefaults *defaults =[NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:@"FirstRun"] == nil) {
        [defaults setValue:@"1strun" forKey:@"FirstRun"];
        [defaults setValue:[NSNumber numberWithBool:YES] forKey:@"auto_login"];
        [defaults setValue:[NSNumber numberWithBool:NO] forKey:@"default_speaker"];
        [defaults setValue:[NSNumber numberWithBool:YES] forKey:@"default_dial_feedback"];
        [defaults setValue:[NSNumber numberWithBool:YES] forKey:@"vibrate"];
    }

    // If there is no config file in the document dir, copy the default 
    // config file into the directory
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *cfgPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"/config.cfg"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:cfgPath]) {
        NSString *resPath = [[NSBundle mainBundle] pathForResource:@"config" ofType:@"cfg"];
        NSString *cfg = [NSString stringWithContentsOfFile:resPath encoding:NSASCIIStringEncoding error:NULL];
        [cfg writeToFile:cfgPath atomically:NO encoding:NSASCIIStringEncoding error:NULL];
    }
    [cfgPath getCString:argv[2] maxLength:PATH_LENGTH encoding:NSASCIIStringEncoding];    

    app_running = false;
    thread_quit = false;

    // preload user dictionary for matching names
    [PhoneNumber preload];

	self.extensions = [NSArray array];
    accountsManager = [[SIPAccountManager alloc] init];

    // initialize pjsua thread
    [self performSelectorOnMainThread:@selector(init_pjsip) withObject:nil waitUntilDone:YES];

    // start reachability agents
	internetReach = [Reachability reachabilityForInternetConnection];

    return YES;
}

// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
- (void)applicationWillResignActive:(UIApplication *)application
{
#ifdef USE_DTMF_DIAL_SOUND
    // disconnect the dialer from the bridge
    [self disconnect_dialer];
#endif
}

// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [self performSelectorOnMainThread:@selector(keepAlive)
                           withObject:nil
                        waitUntilDone:YES];
    
    [application setKeepAliveTimeout:KEEP_ALIVE_INTERVAL handler: ^{
        [self performSelectorOnMainThread:@selector(keepAlive)
                               withObject:nil
                            waitUntilDone:YES];
    }];
}

// Called as part of the transition from the background to the inactive state; 
// here you can undo many of the changes made on entering the background.
- (void)applicationWillEnterForeground:(UIApplication *)application
{
}

// Restart any tasks that were paused (or not yet started) while the application 
// was inactive. If the application was previously in the background, optionally 
// refresh the user interface.
- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // remove any application badges
    application.applicationIconBadgeNumber = 0;

#ifdef USE_DTMF_DIAL_SOUND
    // connect up the dialer to bridge if necessary
    [self connect_dialer];
#endif
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    [[NSUserDefaults standardUserDefaults] synchronize];
    [application clearKeepAliveTimeout];
    [internetReach stopNotifier];
}

- (void)dealloc {
	internetReach = nil;
    thread_quit = true;
    
    [self deinit_pjsip];

    [NSThread sleepForTimeInterval:SLEEP_INTERVAL];
}

#pragma mark - PJSIP threading support

pj_thread_t *main_thread = NULL;
pj_thread_desc main_thread_desc;
pj_thread_t *background_thread = NULL;
pj_thread_desc background_thread_desc;

-(void)register_main_thread {
    pj_thread_register("main", main_thread_desc, &main_thread);
}

-(void)deregister_main_thread {
    if (!pj_thread_is_registered() && main_thread != NULL) {
        pj_thread_destroy(main_thread);
    }    
}

#pragma mark - PJSIP

- (void)init_pjsip 
{
    // reset restart state
    app_restart = PJ_FALSE;
    if (jazinga_init_pjsip() != PJ_SUCCESS) {
        NSString *str = @"Failed to initialize pjsua\n";
        [self performSelectorOnMainThread:@selector(fatal:) 
                               withObject:str 
                            waitUntilDone:YES];
    }

#ifdef USE_DTMF_DIAL_SOUND
    [self init_dialer_tonegen];
#endif

    // mark app as running
    app_running = true;
    
    // start PJSUA
    pj_status_t status = pjsua_start();
    if (status != PJ_SUCCESS) {
        jazinga_destroy_pjsip();
        return;
    }
}

- (void)deinit_pjsip
{
#ifdef USE_DTMF_DIAL_SOUND
    [self deinit_dialer_tonegen];
#endif
    [self deregister_main_thread];
}

char* getInput(char *s, int n, FILE *stream)
{
    if (stream != stdin) {
        return fgets(s, n, stream);
    }

    while (!thread_quit) {
        [NSThread sleepForTimeInterval:(SLEEP_INTERVAL * 4)];
    }
    
    return s;
}

void showMsg(const char *format, ...)
{
    @autoreleasepool {
        va_list arg;
        va_start(arg, format);
    
#if DEBUGGER_PRINT
        NSString *str = [[NSString alloc] initWithFormat:[NSString stringWithFormat:@"%s", format] arguments: arg];
        //NSLog(@"%@", str);
#endif

        va_end(arg);
    }
}

void showLog(int level, const char *data, int len)
{
    showMsg("%s", data);
}

pj_bool_t showNotification(pjsua_call_id call_id) 
{
	[[AppDelegate sharedAppDelegate] handleIncomingCall:call_id];
    return PJ_FALSE;
}

- (void)handleIncomingCall:(pjsua_call_id)call_id {
	// Create a new notification
    @autoreleasepool {
        UILocalNotification* alert = [[UILocalNotification alloc] init];
        alert.repeatInterval = 0;
        alert.alertBody = @"Incoming call received...";
        alert.alertAction = @"Answer";
        alert.hasAction = YES;
        alert.soundName = UILocalNotificationDefaultSoundName;
        alert.applicationIconBadgeNumber = [UIApplication sharedApplication].applicationIconBadgeNumber + 1;
        
		id notificationID = [NSNumber numberWithInt:call_id];

        struct pjsua_call_info info;
        memset(&info, 0, sizeof(info));
        pj_status_t status = pjsua_call_get_info(call_id, &info);
        if (status == PJ_SUCCESS) {
            NSString *sipCallerNumber = [NSString stringWithCString:pj_strbuf(&info.remote_contact)
                                                           encoding:NSUTF8StringEncoding];
            NSString *sipDisplayName = [NSString stringWithCString:pj_strbuf(&info.remote_info)
                                                          encoding:NSUTF8StringEncoding];
            NSString *callerDisplay = [SIPCallDetails parseSipDisplayName:sipDisplayName];
            NSString *callerNumber = [SIPCallDetails parseSipCallerNumber:sipCallerNumber];
            
            alert.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              notificationID, @"callId",
                              [NSString stringWithString:callerDisplay], @"callerDisplay",
                              [NSString stringWithString:callerNumber], @"callerNumber",
                              [NSNumber numberWithDouble:[[NSDate date] timeIntervalSinceReferenceDate]], @"callStartTime",
							  nil];
			
            alert.alertBody = [NSString stringWithFormat:@"Incoming call from %@", callerDisplay];
        }
		
		// start vibration timer if needed
		BOOL shouldVibrate = [[NSUserDefaults standardUserDefaults] boolForKey:@"vibrate"];
		if (shouldVibrate == YES) {
			[self startBackgroundOperations];
			[self startVibrate];
		}

        // save notification in case we need to cancel it later
		[pendingNotifications setValue:alert forKey:notificationID];

        [[UIApplication sharedApplication] presentLocalNotificationNow:alert];
    }
}

#pragma mark - Invoked SIP methods

- (BOOL)calls_in_progress
{
    return pjsua_call_get_count() > 0;
}

-(void)answer_call:(pjsua_call_id)call_id {
    if (!pj_thread_is_registered()) {
        pj_thread_register(PJSIP_THREAD_NAME, a_thread_desc, &a_thread);
    }
    pjsua_call_answer(call_id, 200, NULL, NULL);
}

-(void)decline_call:(pjsua_call_id)call_id {
    if (!pj_thread_is_registered()) {
        pj_thread_register(PJSIP_THREAD_NAME, a_thread_desc, &a_thread);
    }
    pjsua_call_hangup_all();
}

- (void)call:(NSString*)name withNumber:(NSString*)number {
    // handle calls to SIP URLs differently
    if ([number hasPrefix:@"sip:"]) {
        [self call:name withSipUrl:number];
        return;
    }
        
    // check for network
    if (internetReach.currentReachabilityStatus == NotReachable) {
        [self showAlert:@"Cannot Make Call" 
            withMessage:@"Jazinga cannot initiate the VOIP call because it is not connected to the Internet."];
        return;
    }
    
    if (!pj_thread_is_registered()) {
        pj_thread_register(PJSIP_THREAD_NAME, a_thread_desc, &a_thread);
    }

    pjsua_acc_id active_acc_id = [accountsManager activeAccount];
    if (active_acc_id == PJSUA_INVALID_ID) {
        [self showAlert:@"Cannot Make Call"
            withMessage:@"Jazinga cannot initiate the VOIP call because there are no SIP sessions currently registered."];
        return;
    }
    
    pjsua_call_id call_id = PJSUA_INVALID_ID;
    pjsua_call_setting opt;
    pjsua_call_setting_default(&opt);
        
    // use registrar URL as base URL for outgoing call
    pjsua_acc_config acfg;
    pjsua_acc_get_config(active_acc_id, &acfg);
    NSString *baseURL = [NSString stringWithCString:pj_strbuf(&acfg.reg_uri)
                                           encoding:NSUTF8StringEncoding];
    NSString *sipURL = [baseURL stringByReplacingOccurrencesOfString:@"sip:" withString:@""];

    // build SIP call To header
    NSString *sipURI = [NSString stringWithFormat:@"sip:%@@%@", 
                         [[PhoneNumber normalize:number] urlEncodeUsingEncoding:NSUTF8StringEncoding], sipURL, nil];
    const pj_str_t call = pj_str((char*)[sipURI cStringUsingEncoding:NSUTF8StringEncoding]);
    
    // create call details to attach to call
    SIPCallDetails *scp = [SIPCallDetails withCallID:call_id 
                                                type:CallTypeOutbound 
                                                name:name 
                                              number:number];
    pj_status_t status = pjsua_call_make_call(active_acc_id, &call, &opt, (__bridge void*)scp, NULL, &call_id);
    if (status == PJ_SUCCESS) {
        scp.callID = call_id;
        return;
    } else {
        char ebuf[1024];
        pjsip_strerror(status, ebuf, sizeof(ebuf));
        DebugLog(@"error: %s", ebuf);
    }
    
    // TODO: handle call failed
    [self showAlert:@"Cannot Make Call" 
        withMessage:@"Jazinga cannot initiate the VOIP call because there are no SIP sessions currently registered."];

    // hack to force sound device close after a bad SIP call
    pjsua_conf_disconnect(0, 0);
}

-(void)call:(NSString*)name withSipUrl:(NSString *)url {
    // check for network
    if (internetReach.currentReachabilityStatus == NotReachable) {
        [self showAlert:@"Cannot Make Call" 
            withMessage:@"Jazinga cannot initiate the VOIP call because it is not connected to the Internet."];
        return;
    }
    
    if (!pj_thread_is_registered()) {
        pj_thread_register(PJSIP_THREAD_NAME, a_thread_desc, &a_thread);
    }
    
    pjsua_acc_id active_acc_id = [accountsManager activeAccount];
    if (active_acc_id == PJSUA_INVALID_ID) {
        [self showAlert:@"Cannot Make Call"
            withMessage:@"Jazinga cannot initiate the VOIP call because there are no SIP sessions currently registered."];
        return;
    }
    
    pjsua_call_id call_id = PJSUA_INVALID_ID;
    pjsua_call_setting opt;
    pjsua_call_setting_default(&opt);
    
     // create call details to attach to call
    SIPCallDetails *scp = [SIPCallDetails withCallID:call_id 
                                                type:CallTypeOutbound
                                                name:name 
                                              number:url];

    const pj_str_t call = pj_str((char*)[url cStringUsingEncoding:NSUTF8StringEncoding]);
    pj_status_t status = pjsua_call_make_call(active_acc_id, &call, &opt, (__bridge void*) scp, NULL, &call_id);
    if (status == PJ_SUCCESS) {
        scp.callID = call_id;
        return;
    } else {
        char ebuf[1024];
        pjsip_strerror(status, ebuf, sizeof(ebuf));
        DebugLog(@"error: %s", ebuf);
    }
    
    // TODO: handle call failed
    [self showAlert:@"Cannot Make Call" 
        withMessage:@"Jazinga cannot initiate the VOIP call because there are no SIP sessions currently registered."];

    // hack to force sound device close after a bad SIP call
    pjsua_conf_disconnect(0, 0);
}

-(void)recordGreeting:(NSString*)greeting caption:(NSString*)caption {
    // check for network
    if (internetReach.currentReachabilityStatus == NotReachable) {
        [self showAlert:@"Cannot Make Call"
            withMessage:@"Jazinga cannot initiate the VOIP call because it is not connected to the Internet."];
        return;
    }
    
    if (!pj_thread_is_registered()) {
        pj_thread_register(PJSIP_THREAD_NAME, a_thread_desc, &a_thread);
    }
    
    pjsua_acc_id active_acc_id = [accountsManager activeAccount];
    if (active_acc_id == PJSUA_INVALID_ID) {
        [self showAlert:@"Cannot Make Call"
            withMessage:@"Jazinga cannot initiate the VOIP call because there are no SIP sessions currently registered."];
        return;
    }
    
    pjsua_call_id call_id = PJSUA_INVALID_ID;
    pjsua_call_setting opt;
    pjsua_call_setting_default(&opt);
    
    // use registrar URL as base URL for outgoing call
    pjsua_acc_config acfg;
    pjsua_acc_get_config(active_acc_id, &acfg);
    NSString *baseURL = [NSString stringWithCString:pj_strbuf(&acfg.reg_uri)
                                           encoding:NSUTF8StringEncoding];
    NSString *sipURL = [baseURL stringByReplacingOccurrencesOfString:@"sip:" withString:@""];
    
    // build SIP call To header
    NSString *name = [NSString stringWithFormat:@"record-%@",greeting, nil];
    NSString *sipURI = [NSString stringWithFormat:@"sip:%@@%@",
                        name, sipURL, nil];
    const pj_str_t call = pj_str((char*)[sipURI cStringUsingEncoding:NSUTF8StringEncoding]);
    
    // create call details to attach to call
    SIPCallDetails *scp = [SIPCallDetails withCallID:call_id
                                                type:CallTypeRecordGreeting
                                                name:caption
                                              number:name];
    pj_status_t status = pjsua_call_make_call(active_acc_id, &call, &opt, (__bridge void*)scp, NULL, &call_id);
    if (status == PJ_SUCCESS) {
        scp.callID = call_id;
        return;
    } else {
        char ebuf[1024];
        pjsip_strerror(status, ebuf, sizeof(ebuf));
        DebugLog(@"error: %s", ebuf);
    }
    
    // TODO: handle call failed
    [self showAlert:@"Cannot Record Greeting"
        withMessage:@"Jazinga cannot record the greeting since there are no SIP sessions currently registered."];

    // hack to force sound device close after a bad SIP call
    pjsua_conf_disconnect(0, 0);
}

- (void)present:(pjsua_call_id)call_id {
    // trivial error checking
    if (call_id == PJSUA_INVALID_ID) return;
    
    SIPCallDetails *scp = (__bridge SIPCallDetails*)pjsua_call_get_user_data(call_id);
    
    // if call type is conference, we already have a call screen up
    if (scp.type != CallTypeConference) {
        [self.window.rootViewController performSegueWithIdentifier:@"OutgoingCall"
                                                        sender:scp];
    }
    
    // don't need the SCD anymore, used by tonegen later
    pjsua_call_set_user_data(call_id, NULL);
}

- (void)cancel:(pjsua_call_id)call_id {
	// if cancelled call is main call and we still have outstanding calls, don't close window
    unsigned int callsOutstanding = pjsua_call_get_count();
	
	// cancel any notification vibrations
	[self stopVibrate];

	// remove pending incoming notification
	id notifID = [NSNumber numberWithInt:call_id];
	UILocalNotification *notification = [pendingNotifications objectForKey:notifID];
	[pendingNotifications removeObjectForKey:notifID];

    // remove the call connection screen
    UIViewController *presented = [self.window.rootViewController presentedViewController];
    if ([presented respondsToSelector:@selector(cancel:)] == YES && callsOutstanding <= 1) {
        [presented performSelectorOnMainThread:@selector(cancel:) 
                                    withObject:[NSNumber numberWithInteger:call_id] 
                                 waitUntilDone:YES];
    } else {
		// replace incoming notification with missed call notification
		[self replaceIncomingForMissingNotification:notification];
		
        // write missed call log entry
        SIPCallDetails *callDetails = [SIPCallDetails withCallID:call_id type:CallTypeMissed];
        AppDelegate *delegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
        NSDate *now = [NSDate date];
        [delegate addCallLogEntry:callDetails
                            start:now
                              end:now];
    }
}

- (void)replaceIncomingForMissingNotification:(UILocalNotification*)notification
{
	// abort if no notification
	if (notification == nil) return;
	
	// get info about missed call
	NSString *callerDisplay = [notification.userInfo objectForKey:@"callerDisplay"];
	
	// cancel incoming call notification (if it exists), replace with missed call
	[[UIApplication sharedApplication] cancelLocalNotification:notification];

	// create new notification
	UILocalNotification* alert = [[UILocalNotification alloc] init];
	alert.repeatInterval = 0;
	alert.alertAction = nil;
	alert.hasAction = NO;
	alert.soundName = UILocalNotificationDefaultSoundName;
	alert.applicationIconBadgeNumber = 0;
	alert.alertBody = [NSString stringWithFormat:@"Missed call from %@", callerDisplay];
	
	// present it to the user now
	[[UIApplication sharedApplication] presentLocalNotificationNow:alert];
}

- (void)active:(pjsua_call_id)call_id {
    // make current call active
    UIViewController *presented = [self.window.rootViewController presentedViewController];
    if ([presented respondsToSelector:@selector(active:)] == YES) {
        [presented performSelectorOnMainThread:@selector(active:) 
                                    withObject:[NSNumber numberWithInteger:call_id] 
                                 waitUntilDone:YES];
    }
}

- (void)hold:(pjsua_call_id)call_id {
    // make current call active
    UIViewController *presented = [self.window.rootViewController presentedViewController];
    if ([presented respondsToSelector:@selector(updateHoldStatus:)] == YES) {
        [presented performSelectorOnMainThread:@selector(updateHoldStatus:) 
                                    withObject:[NSNumber numberWithInteger:call_id] 
                                 waitUntilDone:YES];
    }
}

- (void)transfer:(pjsua_call_id)call_id number:(NSString*)phoneNumber
{
    if (!pj_thread_is_registered()) {
        pj_thread_register(PJSIP_THREAD_NAME, a_thread_desc, &a_thread);
    }
    
    // use registrar URL as base URL for outgoing call
    pjsua_acc_id active_acc_id = [accountsManager activeAccount];
    pjsua_acc_config acfg;
    pjsua_acc_get_config(active_acc_id, &acfg);
    NSString *baseURL = [NSString stringWithCString:pj_strbuf(&acfg.reg_uri)
                                           encoding:NSUTF8StringEncoding];
    NSString *sipURL = [baseURL stringByReplacingOccurrencesOfString:@"sip:" withString:@""];
    
    // build SIP call To header
    NSString *sipURI = [NSString stringWithFormat:@"sip:%@@%@",
                        [PhoneNumber normalize:phoneNumber], sipURL, nil];
    const pj_str_t call = pj_str((char*)[sipURI cStringUsingEncoding:NSUTF8StringEncoding]);
    
    pjsua_call_xfer(call_id, &call, NULL);
}

- (void)add:(pjsua_call_id)call_id number:(NSString*)phoneNumber
{
    if (!pj_thread_is_registered()) {
        pj_thread_register(PJSIP_THREAD_NAME, a_thread_desc, &a_thread);
    }

    pjsua_acc_id active_acc_id = [accountsManager activeAccount];

    pjsua_call_setting opt;
    pjsua_call_setting_default(&opt);
    
    // use registrar URL as base URL for outgoing call
    pjsua_acc_config acfg;
    pjsua_acc_get_config(active_acc_id, &acfg);
    NSString *baseURL = [NSString stringWithCString:pj_strbuf(&acfg.reg_uri)
                                           encoding:NSUTF8StringEncoding];
    NSString *sipURL = [baseURL stringByReplacingOccurrencesOfString:@"sip:" withString:@""];
    
    // build SIP call To header
    NSString *sipURI = [NSString stringWithFormat:@"sip:%@@%@",
                        [PhoneNumber normalize:phoneNumber], sipURL, nil];
    const pj_str_t call = pj_str((char*)[sipURI cStringUsingEncoding:NSUTF8StringEncoding]);
    
    pjsua_call_id new_call_id = PJSUA_INVALID_ID;

    // create call details to attach to call
    SIPCallDetails *scp = [SIPCallDetails withCallID:new_call_id
                                                type:CallTypeConference
                                                name:nil
                                              number:phoneNumber];
    pj_status_t status = pjsua_call_make_call(active_acc_id, &call, &opt,
                                              (__bridge void*) scp, NULL, &new_call_id);
    if (status != PJ_SUCCESS || new_call_id == PJSUA_INVALID_ID) return; // BUGBUG: handle error properly

    // update call id ... autoconf feature will automatically put this call into conference
    scp.callID = new_call_id;
}

#pragma mark - Tone generator for dialer sounds

- (void)init_dialer_tonegen
{
    pj_pool_t *pool;
    
    pool = pjsua_pool_create("dialer", 512, 512);
    dialer_data = PJ_POOL_ZALLOC_T(pool, struct tonegen_data);
    dialer_data->pool = pool;
    
    pjmedia_tonegen_create(dialer_data->pool, 8000, 1, 160, 16, 0, &dialer_data->tonegen);
    pjsua_conf_add_port(dialer_data->pool, dialer_data->tonegen, &dialer_data->toneslot);
    pjsua_conf_connect(dialer_data->toneslot, AUDIO_SINK_PORT);
    
    // play sounds thru loudspeaker
    pjmedia_aud_dev_route route = PJMEDIA_AUD_DEV_ROUTE_LOUDSPEAKER;
    pjsua_snd_set_setting(PJMEDIA_AUD_DEV_CAP_OUTPUT_ROUTE, &route, PJ_TRUE);
}

- (void)deinit_dialer_tonegen
{
    // use default audio mode (ie: phone headset)
    pjmedia_aud_dev_route route = PJMEDIA_AUD_DEV_ROUTE_DEFAULT;
    pjsua_snd_set_setting(PJMEDIA_AUD_DEV_CAP_OUTPUT_ROUTE, &route, PJ_TRUE);
    
    pjsua_conf_disconnect(dialer_data->toneslot, AUDIO_SINK_PORT);
    pjsua_conf_remove_port(dialer_data->toneslot);
    pjmedia_port_destroy(dialer_data->tonegen);
    
    pj_pool_release(dialer_data->pool);
}

- (void)connect_dialer
{
    // reconnect tonegen to speaker
    pjsua_conf_connect(dialer_data->toneslot, AUDIO_SINK_PORT);
    
    // don't mess with audio if calls are in progress
    if ([self calls_in_progress] == YES) return;
    
    // play sounds thru loudspeaker
    pjmedia_aud_dev_route route = PJMEDIA_AUD_DEV_ROUTE_LOUDSPEAKER;
    pjsua_snd_set_setting(PJMEDIA_AUD_DEV_CAP_OUTPUT_ROUTE, &route, PJ_TRUE);
}

- (void)disconnect_dialer
{
    // disconnect tonegen to speaker
    pjsua_conf_disconnect(dialer_data->toneslot, AUDIO_SINK_PORT);
    
    // don't mess with audio if calls are in progress
    if ([self calls_in_progress] == YES) return;
    
    // play sounds thru loudspeaker
    pjmedia_aud_dev_route route = PJMEDIA_AUD_DEV_ROUTE_DEFAULT;
    pjsua_snd_set_setting(PJMEDIA_AUD_DEV_CAP_OUTPUT_ROUTE, &route, PJ_TRUE);
}

- (tonegen_data*)dialer_tonegen
{
    return dialer_data;
}

- (void)send:(pjsua_call_id)call_id digit:(unichar)digit duration:(NSTimeInterval)duration
{
    // play audio feedback using the tonegenerator
    {
        my_call_data *cd = (my_call_data*) pjsua_call_get_user_data(call_id);
        if (!cd)
            cd = call_init_tonegen(call_id);
        
        pjmedia_tone_digit d;
        d.digit = digit;
        d.on_msec = duration * 1000;
        d.off_msec = 0;
        d.volume = 0;
        
        pjmedia_tonegen_play_digits(cd->tonegen, 1, &d, PJMEDIA_TONEGEN_LOOP);
    }
    
    // but send the DTMF using RFC methods
    char d[16];
    sprintf(d, "%c", digit);
    pj_str_t digits;
    digits = pj_str(d);
    pjsua_call_dial_dtmf(call_id, &digits);
}

- (void)stop_dtmf:(pjsua_call_id)call_id digit:(unichar)digit
{   
    my_call_data *cd = (my_call_data*) pjsua_call_get_user_data(call_id);
    pjmedia_tonegen_stop(cd->tonegen);
}

#pragma mark - Background call notifications

#ifdef __IPHONE_4_0

- (void)application:(UIApplication*)application 
    didReceiveLocalNotification:(UILocalNotification*)notification 
{
    // remove any application badges
    application.applicationIconBadgeNumber = 0;
    
    // get call id
    id callId = [[notification userInfo] valueForKey:@"callId"];
    if (callId == nil) return;
    
	// remove the notification from our pending collection
	[pendingNotifications removeObjectForKey:callId];
	
    // get caller display info
    NSString *callerDisplay = [[notification userInfo] valueForKey:@"callerDisplay"];
    NSString *callerNumber = [[notification userInfo] valueForKey:@"callerNumber"];
    
    // get call info
    pjsua_call_id cid = [callId intValue];
    struct pjsua_call_info info;
    memset(&info, 0, sizeof(info));    
    pj_status_t status = pjsua_call_get_info([callId intValue], &info);
    if (status == PJ_SUCCESS) {
        // create call details info and open inbound call screen
        SIPCallDetails *scd = [SIPCallDetails withCallID:cid
                                                    type:CallTypeInbound
                                                    name:callerDisplay
                                                  number:callerNumber];

        if (pjsua_call_get_count() <= 1) {
            [self.window.rootViewController performSegueWithIdentifier:@"IncomingCall"
                                                                sender:scd];
        } else {
            InboundViewController* ivc = [self.window.rootViewController presentedViewController];
            if ([ivc respondsToSelector:@selector(callOptions:)]) {
                [ivc callOptions:scd];
            }
        }
    }
}

- (void)keepAlive {
    if (!pj_thread_is_registered()) {
        pj_thread_register(PJSIP_THREAD_NAME, a_thread_desc, &a_thread);
    }
    [accountsManager keepAlive:KEEP_ALIVE_INTERVAL];
}

#pragma mark - Vibration support

- (void)startVibrate
{
	self.vibrationTimer = [NSTimer timerWithTimeInterval:4.0f
														   target:self
														 selector:@selector(vibrate)
														 userInfo:nil
														  repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:self.vibrationTimer forMode:NSRunLoopCommonModes];
}

- (void)stopVibrate
{
	[self finishedBackgroundOperations];

	if (self.vibrationTimer == nil) return;
	
	[self.vibrationTimer invalidate];
	self.vibrationTimer = nil;
}

- (void)vibrate
{
	AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

#endif

#pragma mark - Core Data stack

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    if (__managedObjectContext != nil) {
        return __managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        __managedObjectContext = [[NSManagedObjectContext alloc] init];
        [__managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return __managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (__managedObjectModel != nil) {
        return __managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Jazinga" withExtension:@"momd"];
    __managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return __managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (__persistentStoreCoordinator != nil) {
        return __persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Jazinga.sqlite"];
    
    NSError *error = nil;
    __persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![__persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter: 
         [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption, [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }    
    
    return __persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

- (void)saveContext 
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        } 
    }
}

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (void)addCallLogEntry:(SIPCallDetails*)callDetails 
                  start:(NSDate*)start 
                    end:(NSDate*)end
{
    // ignore greeting record calls
    if (callDetails.type == CallTypeRecordGreeting) return;
    
    NSManagedObjectContext *context = [self managedObjectContext];
    Call *call = [NSEntityDescription insertNewObjectForEntityForName:@"Call"
                                               inManagedObjectContext:context];
    
    call.type = [NSNumber numberWithInt:callDetails.type];
    call.name = [callDetails callerDisplay];
    call.phoneNumber = callDetails.phoneNumber;
    call.start = start;
    call.end = end;
    
    // update stored missed call badge value
    if (callDetails.type == CallTypeMissed) {
        NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
        NSInteger missedCalls = [sud integerForKey:@"MissedCalls"];
        missedCalls += 1;
        [sud setInteger:missedCalls forKey:@"MissedCalls"];
    }
    
    // attempt to match phone number to contact
    call.contact = nil;
    NSDictionary *matchResults = [PhoneNumber match:callDetails.phoneNumber];
    if (matchResults != nil) {
        Contact *contact = [NSEntityDescription insertNewObjectForEntityForName:@"Contact" 
                                                         inManagedObjectContext:context];
        contact.call = call;
        contact.contactID = [matchResults objectForKey:@"contactID"];
        contact.valueID = [matchResults objectForKey:@"valueID"];

        call.contact = contact;
    }

    [context save:NULL];
}

#pragma mark - Error alert code

- (void)showAlert:(NSString*)title withMessage:(NSString*)message
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title 
                                                    message:message 
                                                   delegate:(id)nil 
                                          cancelButtonTitle:nil
                                          otherButtonTitles:@"Ok", nil];
    [alert show];
}

- (void)fatal:(NSString*)message {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" 
                                                    message:message 
                                                   delegate:(id)nil 
                                          cancelButtonTitle:nil
                                          otherButtonTitles:@"Ok", nil];
    [alert show];
}

#pragma mark - Background task support

- (void)startBackgroundOperations
{
    // see if we're backgrounded already
    if (bgBackgroundTask != UIBackgroundTaskInvalid) return;
	
    // start background task
    bgBackgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        // call this at end of task
        [[UIApplication sharedApplication] endBackgroundTask:bgBackgroundTask];
        bgBackgroundTask = UIBackgroundTaskInvalid;
    }];
}

- (void)finishedBackgroundOperations
{
    // see if we're backgrounded
    if (bgBackgroundTask == UIBackgroundTaskInvalid) return;
    
    // finish background task
    [[UIApplication sharedApplication] endBackgroundTask:bgBackgroundTask];
    bgBackgroundTask = UIBackgroundTaskInvalid;
}

#pragma mark - Extensions support

- (NSArray*)extensions {
	return extensions;
}

- (void)setExtensions:(NSArray*)xtns
{
	extensions = xtns;
	[[NSNotificationCenter defaultCenter] postNotificationName:kExtensionsChangedNotification object:self];
}

- (NSArray*)teams {
	return teams;
}

- (void)setTeams:(NSArray*)xtns
{
	teams = xtns;
	[[NSNotificationCenter defaultCenter] postNotificationName:kExtensionsChangedNotification object:self];
}

- (NSArray*)apps {
	return apps;
}

- (void)setApps:(NSArray*)xtns
{
	apps = xtns;
	[[NSNotificationCenter defaultCenter] postNotificationName:kExtensionsChangedNotification object:self];
}

@end
