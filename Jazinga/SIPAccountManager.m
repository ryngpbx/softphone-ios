//
//  SIPAccountManager.m
//  Jazinga
//
//  Created by John Mah on 12-07-27.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import "SIPAccountManager.h"
#import "AppDelegate.h"
#import "UIDevice+Identifier.h"
#import "NSString+URLEncoding.h"
#import "NSDictionary_JSONExtensions.h"
#import "SIPWrapper.h"
#import "Extension.h"

UIBackgroundTaskIdentifier bgReconnectTask;
UIBackgroundTaskIdentifier bgReachabilityTask;

extern pjsua_transport_id tcp_transport_id;

NSString *const kSIPRegistrationChangedNotification = @"kSIPRegistrationChangedNotification";

@implementation SIPAccountManager

@synthesize localAccount;
@synthesize remoteAccount;
@synthesize active;
@synthesize localReach;
@synthesize remoteReach;
@synthesize forceRemote;
@synthesize loginDelegate;
@synthesize reach;

+ (SIPAccountManager*)sharedAccountManager
{
	@autoreleasepool {
		return [[AppDelegate sharedAppDelegate] accountsManager];
	}
}

- (id)init {
    if (self = [super init]) {
        bgReconnectTask = UIBackgroundTaskInvalid;
        bgReachabilityTask = UIBackgroundTaskInvalid;
        
        localAccount = nil;
        remoteAccount = nil;
        active = nil;
        forceRemote = NO;
        reach = [Reachability reachabilityForInternetConnection];
        [reach startNotifier];
        
        // add listener for reachability events
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reachabilityChanged:)
                                                     name:kReachabilityChangedNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    // add listener for reachability events
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kReachabilityChangedNotification
                                                  object:nil];

    [self reset];
}

// return a valid acc_id to use for sip operations
- (pjsua_acc_id)activeAccount
{
    // enumerate current accounts
    pjsua_acc_id acc_ids[16];
    unsigned count = PJ_ARRAY_SIZE(acc_ids);
    pjsua_enum_accs(acc_ids, &count);

    pjsua_acc_id acc_id = PJSUA_INVALID_ID;
    for (int i = 0; i < count; i++) {
        // if account isn't valid try next one
        if (pjsua_acc_is_valid(i) == PJ_FALSE) continue;
        
        // check account registration status
        pjsua_acc_info ai;
        pjsua_acc_get_info(acc_ids[i], &ai);
            
        // don't attempt to call if this account has no registration
        if (ai.status == 0 
            || ai.status == PJSIP_SC_TRYING 
            || ai.status == PJSIP_SC_REQUEST_TIMEOUT
            || ai.status == PJSIP_SC_SERVICE_UNAVAILABLE) continue;
        
        // we have a winner
        acc_id = acc_ids[i];
    }
    
    return acc_id;
}

- (void)setLocalAccount:(NSMutableDictionary *)account
{
    localAccount = account;
    if (account == nil) return;

    // reachability for this host
    NSString *host = [account objectForKey:@"host"];
    localReach = [Reachability reachabilityWithHostname:host];
    [localReach startNotifier];
}

- (void)setRemoteAccount:(NSMutableDictionary *)account
{
    remoteAccount = account;
    if (account == nil) return;

    // reachability for this host
    NSString *host = [account objectForKey:@"host"];
    
    remoteReach = [Reachability reachabilityWithHostname:host];
    [remoteReach startNotifier];
}

- (void)start
{
    // find a suitable host
    [self useReachableHost];
}

- (BOOL)useReachableHost
{
    // trivial error check
    if (localAccount == nil || remoteAccount == nil) return NO;

    // get internet reachability
    BOOL hasWifi = [reach isReachableViaWiFi];
    BOOL hasWWAN = [reach isReachableViaWWAN];
    
    // get reachability flags for host options
    BOOL isLocalAvailable = [localReach isReachableViaWiFi] && [localReach isDirect] && hasWifi && forceRemote == NO;
    BOOL isRemoteAvailable = [remoteReach isReachable] && (hasWWAN || hasWifi);

    // preference is local host
    if (isLocalAvailable && active != localAccount) {
        DebugLog(@"Attempting to register with local account", nil);
        [self tryAccount:localAccount];
        return YES;
    } else if (isRemoteAvailable) {
        DebugLog(@"Attempting to register with remote account", nil);
        [self tryAccount:remoteAccount];
        return YES;
    }
    
    // no suitable host found
    return NO;
}

- (void)tryAccount:(NSMutableDictionary*)account
{
    [self startBackgroundOperations];

    [self killAllRegistrations];
    [self startRegistration:account];
    active = account;
}

- (void)updateAccountRegistration:(NSMutableDictionary*)account
{
    [self startBackgroundOperations];

    // force re-registration on the account
    NSNumber *nid = [account objectForKey:@"acc_id"];
    int acc_id = [nid integerValue];
    if (pjsua_acc_is_valid(acc_id) == true)
        pjsua_acc_set_registration(acc_id, PJ_TRUE);
}

- (void)activeFailedRegistration:(pjsua_acc_id)acc_id
{
	// this makes sure the change notification happens on the MAIN THREAD
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kSIPRegistrationChangedNotification
                                                            object:self];
    });
	
	// notify any login screens that registration failed
	[self registrationFailed];

    // if active account failed, then always use remote until network type changes
    if (active == localAccount) {
        forceRemote = YES;
        [self tryAccount:remoteAccount];
        return;
    }
}

- (void)activeSuccessfulRegistration:(pjsua_acc_id)acc_id
{
	// notify any login screens that registration failed
	[self registrationSuccess];
	
	// this makes sure the change notification happens on the MAIN THREAD
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kSIPRegistrationChangedNotification
                                                            object:self];
    });

    [self finishedBackgroundOperations];
}

- (BOOL)hasValidRegistration
{
	// check for internet access
	if ([reach currentReachabilityStatus] == NO)
		return NO;
	
	// check for some valid accounts
	if ([self activeAccount] != PJSUA_INVALID_ID)
		return YES;
	
	return NO;
}

#define TCP_APPENDER    @";transport=TCP"
#define REALM           @"asterisk"

+ (NSMutableDictionary*)createAccountInfo:(NSString*)sipURI
{
    // ignore prefix 'sip://'
    NSArray *components = [[sipURI substringFromIndex:6] componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":/@"]];
    if ([components count] < 3) return nil;
    
    // format our pjsip parameters (BUGBUG: assumes 4 parameters in URI)
    NSString* username = [components objectAtIndex:0];
    NSString* password = [components objectAtIndex:1];
    NSString* host = [components objectAtIndex:2];
    NSString* port = [components objectAtIndex:3];
    NSString* uri = [NSString stringWithFormat:@"sip:%@@%@:%@%@", username, host, port, TCP_APPENDER, nil];
    NSString *registrar = [NSString stringWithFormat:@"sip:%@:%@%@", host, port, TCP_APPENDER, nil];
    
    NSMutableDictionary *account = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    username,@"username",
                                    password,@"password",
                                    REALM,@"realm",
                                    host,@"host",
                                    port,@"port",
                                    uri,@"uri",
                                    registrar,@"registrar",
                                    nil];
    return account;
}

+ (NSMutableDictionary*)createStaticAccountInfo:(NSString*)username
                                       password:(NSString*)password
                                           host:(NSString*)host
                                           port:(NSString*)port
                                         useTCP:(BOOL)useTCP
{
    // build a SIP URI and registrar
    NSString* uri = [NSString stringWithFormat:@"sip:%@@%@:%@%@", username, host, port, (useTCP ? TCP_APPENDER : @""), nil];
    NSString* registrar = [NSString stringWithFormat:@"sip:%@:%@%@", host, port, (useTCP ? TCP_APPENDER : @""), nil];
    
    NSMutableDictionary *account = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    username,@"username",
                                    password,@"password",
                                    host,@"realm",
//                                    REALM,@"realm",
                                    host,@"host",
                                    port,@"port",
                                    uri,@"uri",
                                    registrar,@"registrar",
                                    nil];
    return account;
}

- (pj_status_t)startRegistration:(NSMutableDictionary*)hd
{
    BOOL isLocalAccount = (hd == localAccount);

    // format our pjsip parameters (BUGBUG: assumes 4 parameters in URI)
    const char* uname = [[hd objectForKey:@"username"] cStringUsingEncoding:NSUTF8StringEncoding];
    const char* passwd = [[hd objectForKey:@"password"] cStringUsingEncoding:NSUTF8StringEncoding];
    const char *uri = [[hd objectForKey:@"uri"] cStringUsingEncoding:NSUTF8StringEncoding];
    const char *registrar = [[hd objectForKey:@"registrar"] cStringUsingEncoding:NSUTF8StringEncoding];
    const char* realm = [[hd objectForKey:@"realm"] cStringUsingEncoding:NSUTF8StringEncoding];

    pjsua_acc_config acc_cfg;
    pjsua_acc_config_default(&acc_cfg);
    acc_cfg.reg_timeout = KEEP_ALIVE_INTERVAL;
    acc_cfg.reg_first_retry_interval = (isLocalAccount ? 15 : 0);
    acc_cfg.register_on_acc_add = PJ_TRUE;
    acc_cfg.id = pj_str((char*)uri);
    acc_cfg.reg_uri = pj_str((char*)registrar);
    acc_cfg.cred_count = 1;
    acc_cfg.cred_info[0].scheme = pj_str("Digest");
    acc_cfg.cred_info[0].realm = pj_str((char*)realm);
    acc_cfg.cred_info[0].username = pj_str((char*)uname);
    acc_cfg.cred_info[0].data_type = 0;
    acc_cfg.cred_info[0].data = pj_str((char*)passwd);
    acc_cfg.rtp_cfg = app_config.rtp_cfg;

    pjsua_acc_id acc_id = PJSUA_INVALID_ID;
    pj_status_t status = pjsua_acc_add(&acc_cfg, PJ_FALSE, &acc_id);
    if (status != PJ_SUCCESS) return status;
    
    [hd setObject:[NSNumber numberWithInteger:acc_id] forKey:@"acc_id"];
    
    return PJ_SUCCESS;
}

- (void)killRegistration:(pjsua_acc_id)acc_id
{
    // remove account from reg attempts
    if (pjsua_acc_is_valid(acc_id) == PJ_TRUE)
        pjsua_acc_del(acc_id);
}

- (void)killAllRegistrations
{
    // get list of current accounts
    pjsua_acc_id acc_ids[16];
    unsigned count = PJ_ARRAY_SIZE(acc_ids);
    pjsua_enum_accs(acc_ids, &count);
    for (int i=0; i<(int)count; ++i) {
        [self killRegistration:acc_ids[i]];
    }
}

- (void)reset
{
    [self killAllRegistrations];

    [localReach stopNotifier];
    [remoteReach stopNotifier];
    [reach stopNotifier];

    forceRemote = NO;
    localAccount = nil;
    remoteAccount = nil;
    active = nil;
}

#pragma mark - Login methods

- (void)authenticateUser:(NSString*)user
            withPassword:(NSString*)password
				delegate:(id<JazingaLoginDelegate>)delegate
{
    if ([reach currentReachabilityStatus] == NotReachable) {
        [delegate authenticationFailedWithMessage:@"Jazinga cannot login into the VOIP system because it is not connected to the Internet."];
        [delegate didFinishAuthentication];
        return;
    }
	
    // construct POST data
    NSString *clientId = [[UIDevice currentDevice] uniqueGlobalDeviceIdentifier];
    NSString *postData = [NSString stringWithFormat:@"username=%@;password=%@;unique_client_id=%@;format=json;request_version=%u;build_number=%u;architecture=%@;",
                          [user urlEncodeUsingEncoding:NSUTF8StringEncoding],
                          [password urlEncodeUsingEncoding:NSUTF8StringEncoding],
                          [clientId urlEncodeUsingEncoding:NSUTF8StringEncoding],
                          SOFTPHONE_API_VERSION,
                          BUILD_NUMBER,
                          BUILD_ARCHITECTURE, nil];
    NSData *myRequestData = [postData dataUsingEncoding:NSUTF8StringEncoding];
    
    // create request
    NSString *serverUrl = @JAZINGA_AUTHENTICATION_URL;
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:serverUrl]];
    [request setHTTPMethod: @"POST"];
    [request setHTTPBody: myRequestData];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    // notify delegate that we are about to start authentication
    [delegate didStartAuthentication];
    
    // send request
    NSHTTPURLResponse* response = nil;
    NSError* error = nil;
    NSData *returnData = [NSURLConnection sendSynchronousRequest:request
                                               returningResponse:&response
                                                           error:&error];
    if (error != nil) {
        [delegate authenticationFailedWithMessage:[error localizedDescription]];
        [delegate didFinishAuthentication];
        return;
    };
    
    NSDictionary *json = [NSDictionary dictionaryWithJSONData:returnData error:&error];
    DebugLog(@"Send result: %@", json);
    
    // check for request syntax error before checking request status
    NSString *err = [json valueForKey:@"error"];
    if ([err boolValue] == YES) {
        [delegate authenticationFailedWithMessage:@"Application is out of date. Please update."];
        [delegate didFinishAuthentication];
        return;
    }
    
    // check for request error
    NSString *success = [json valueForKey:@"success"];
    if ([success boolValue] == NO) {
        [delegate authenticationFailedWithMessage:[self extractErrorMessage:json]];
        [delegate didFinishAuthentication];
        return;
    };
    
    BOOL loginSuccessful = false;
    NSDictionary *document = [json valueForKey:@"document"];
    
    // save session id
    NSString *sessionID = [document valueForKey:@"session_id"];
    if (sessionID != nil)
        [[NSUserDefaults standardUserDefaults] setObject:sessionID forKey:@"session_id"];
     NSDictionary *services = [document valueForKey:@"services"];
    
	// build list of extensions from JSON
#ifdef TEST_JSON
	NSDictionary *directory = [NSDictionary dictionary];//[services valueForKey:@"directory"];
	if (directory != nil) {
		NSDictionary *document = [NSDictionary dictionary];//[directory valueForKey:@"document"];
		if (document != nil) {
			[self parseExtensions:document];
		}
	}
#endif

	NSDictionary *directory = [services valueForKey:@"directory"];
	if (directory != nil) {
		NSDictionary *document = [directory valueForKey:@"document"];
		if (document != nil) {
			[self parseExtensions:document];
		}
	}

    // save out-of-office value
    NSDictionary *settings = [services valueForKey:@"settings"];
    if (settings != nil) {
        NSDictionary *document = [settings valueForKey:@"document"];
        if (document != nil) {
            BOOL oof = [[document valueForKey:@"out_of_office"] boolValue];
            [[NSUserDefaults standardUserDefaults] setBool:oof forKey:@"out_of_office"];
        }
    }

#ifndef USE_STATIC_ACCOUNT
    // add all accounts to PJSUA account system
    NSArray *sipProxies = [services valueForKey:@"sip_proxies"];
    if ([sipProxies count] < 1) return;
    
    NSDictionary *nextSipProxyEntry = [sipProxies objectAtIndex:0];
    NSString *nextSipProxyURI = [nextSipProxyEntry valueForKey:@"uri"];
    DebugLog(@"Local SIP Proxy: %@", nextSipProxyURI);
    NSMutableDictionary *localHostDictionary = [SIPAccountManager createAccountInfo:nextSipProxyURI];
    self.localAccount = localHostDictionary;
    
    nextSipProxyEntry = [sipProxies objectAtIndex:1];
    nextSipProxyURI = [nextSipProxyEntry valueForKey:@"uri"];
    DebugLog(@"Remote SIP Proxy: %@", nextSipProxyURI);
    NSMutableDictionary *remoteHostDictionary = [SIPAccountManager createAccountInfo:nextSipProxyURI];
    self.remoteAccount = remoteHostDictionary;
#else
    NSMutableDictionary *localHostDictionary = [SIPAccountManager createStaticAccountInfo:@"110512_john"
                                                                                 password:@"D3rpD3rp2020"
                                                                                     host:@"toronto.voip.ms"
                                                                                     port:@"5060"
                                                                                   useTCP:NO];
    self.localAccount = localHostDictionary;

    NSMutableDictionary *remoteHostDictionary = [SIPAccountManager createStaticAccountInfo:@"110512_john"
                                                                                 password:@"D3rpD3rp2020"
                                                                                     host:@"toronto2.voip.ms"
                                                                                     port:@"5060"
                                                                                   useTCP:NO];
    self.remoteAccount = remoteHostDictionary;
#endif

    loginSuccessful = YES;
	self.loginDelegate = delegate;
	
    // now attempt registration on suitable host account
    [self useReachableHost];
}

- (NSArray*)parseExtensionArray:(NSArray*)list
{
	// iterate over list of extensions and build list of extension objects
	NSMutableArray *extensions = [NSMutableArray arrayWithCapacity:[list count]];

	// trivial error check
	if (list == nil) return nil;
	
	for (NSDictionary *extension in list) {
		NSString *name = [extension objectForKey:@"name"];
		NSString *number = [extension objectForKey:@"extension"];
		if (name != nil && number != nil) {
			Extension *next = [Extension extensionWithName:name phoneNumber:number];
			[extensions addObject:next];
		}
	}

	return extensions;
}

-(void)parseExtensions:(NSDictionary*)json
{
#ifdef TEST_JSON
	NSString *testJSON = @"{ \
			\"people\" : \
			[ \
				{ \"name\" : \"Simon Ditner\", \"extension\" : \"104\" }, \
			   	{ \"name\" : \"Randy Busch\", \"extension\" : \"101\" } \
			], \
			\"teams\" : \
			[ \
			  	{ \"name\" : \"Everyone\", \"extension\" : \"201\" } \
			], \
			\"apps\" : \
			[ \
				{ \"name\" : \"Auto Attendant\", \"extension\" : \"3030\" } \
			] \
	}";
	NSData *data = [testJSON dataUsingEncoding:NSUTF8StringEncoding];
	NSError *err = nil;
	NSDictionary *json = [NSDictionary dictionaryWithJSONData:data error:&err];
#endif

	// trivial error check
	if (json == nil) return;

	// sort extensions
	NSSortDescriptor *nameDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name"
																   ascending:YES];
	NSArray *sortDescriptors = @[nameDescriptor];

	// build list of people extensions
	NSArray *people = [self parseExtensionArray:[json valueForKey:@"people"]];
	NSArray *sortedPeople = [people sortedArrayUsingDescriptors:sortDescriptors];
	[[AppDelegate sharedAppDelegate] setExtensions:sortedPeople];

	NSArray *teams = [self parseExtensionArray:[json valueForKey:@"teams"]];
	NSArray *sortedTeams = [teams sortedArrayUsingDescriptors:sortDescriptors];
	[[AppDelegate sharedAppDelegate] setTeams:sortedTeams];

	NSArray *apps = [self parseExtensionArray:[json valueForKey:@"apps"]];
	NSArray *sortedApps = [apps sortedArrayUsingDescriptors:sortDescriptors];
	[[AppDelegate sharedAppDelegate] setApps:sortedApps];
}

-(void)registrationSuccess {
	// only notify delegate if logging in
	if (loginDelegate == nil) return;
	
	// notify delegate that we logged in successfully
	[loginDelegate authenticated];
    
    // notify delegate that we finished authentication
    [loginDelegate didFinishAuthentication];
	
	// no longer need registration updates
	loginDelegate = nil;
}

-(void)registrationFailed {
	// only notify delegate if logging in
	if (loginDelegate == nil) return;
	
	// failed registration -- so report error
	[loginDelegate authenticationFailedWithMessage:@"Unable to find a valid SIP proxy for this account."];
	
    // notify delegate that we finished authentication
    [loginDelegate didFinishAuthentication];

	// no longer need registration updates
	loginDelegate = nil;
}

-(void)registerAccounts
{
    // register accounts
    pj_status_t s = [self startRegistration:self.remoteAccount];
    s = [self startRegistration:self.localAccount];
}

- (NSString*)extractErrorMessage:(NSDictionary*)json {
    NSString *error = [json valueForKey:@"errors"];
    if (error != nil && [[error self] isKindOfClass:[NSString class]])
        return error;
    
    return [NSString stringWithFormat:@"Unknown error.", nil];
}

- (void)logout {
    // remove current accounts
    [self reset];
    
    // unregister keepAlive function
    [[UIApplication sharedApplication] clearKeepAliveTimeout];
}

- (BOOL)isLoggedIn {
    // get list of current accounts
    pjsua_acc_id acc_ids[16];
    unsigned count = PJ_ARRAY_SIZE(acc_ids);
    pjsua_enum_accs(acc_ids, &count);
    
    return count > 0;
}

- (void)keepAlive:(int)timeout {
    // trivial error check
    if (active == nil) return;
    
    // force re-registration on the active account
    pjsua_acc_id acc_id = [self activeAccount];
    if (pjsua_acc_is_valid(acc_id) == true) {
        pjsua_acc_set_registration(acc_id, PJ_TRUE);
    }
}

#pragma mark - Background task support

- (void)startBackgroundOperations
{
    // see if we're backgrounded already
    if (bgReconnectTask != UIBackgroundTaskInvalid) return;

    // start background task
    bgReconnectTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        // call this at end of task
        [[UIApplication sharedApplication] endBackgroundTask:bgReconnectTask];
        bgReconnectTask = UIBackgroundTaskInvalid;
    }];
}

- (void)finishedBackgroundOperations
{
    // see if we're backgrounded
    if (bgReconnectTask == UIBackgroundTaskInvalid) return;
    
    // finish background task
    [[UIApplication sharedApplication] endBackgroundTask:bgReconnectTask];
    bgReconnectTask = UIBackgroundTaskInvalid;
}

#pragma mark - Reachability support

- (void)reachabilityChanged:(NSNotification*)sender
{
    // run the change code as background
    if (bgReachabilityTask == UIBackgroundTaskInvalid) {
        bgReachabilityTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            // call this at end of task
            [[UIApplication sharedApplication] endBackgroundTask: bgReachabilityTask];
            bgReachabilityTask = UIBackgroundTaskInvalid;
        }];
    }

    Reachability *r = (Reachability*)[sender object];
    [self updateWithReachability:r];

    // get current network status
    NetworkStatus currentNetworkStatus = [r currentReachabilityStatus];
    
    // check for connectivity
    BOOL hasConnectivity = currentNetworkStatus != NotReachable;
    if (r == reach && hasConnectivity == NO) {
        pjsua_call_hangup_all();
        return;
    }

#ifdef NETWORK_SWITCH_OPTION_1
    if (r == localReach && currentNetworkStatus != NotReachable && ![r connectionRequired]) {
        jazinga_restart_pjsip();
		
		[self setForceRemote:NO];
		[self useReachableHost];
    } else if (r == remoteReach && active == localAccount) {
		// ignore changes in remote account reachability if we are using local
	} else {
		[self setForceRemote:NO];
		[self useReachableHost];
    }
#endif /* NETWORK_SWITCH_OPTION_1 */

#ifdef NETWORK_SWITCH_OPTION_2
    // handle change in network interface
    if (r == localReach && currentNetworkStatus != NotReachable && ![r connectionRequired]) {
        ip_change();
    }

    // re-register accounts if network types have changed
    bool reachable = [localReach isReachableViaWiFi] && [localReach isDirect];
    if (reachable && active != localAccount) {
        DebugLog(@"==== local host is reachable ====", nil);
        [self tryAccount:localAccount];
    } else if (!reachable && active != remoteAccount) {
        DebugLog(@"==== local host is NOT reachable ====", nil);
        [self tryAccount:remoteAccount];
    }
#endif /* NETWORK_SWITCH_OPTION_2 */

    // mark background task as being finished
    if (bgReachabilityTask != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:bgReachabilityTask];
        bgReachabilityTask = UIBackgroundTaskInvalid;
    }
}

-(void)updateWithReachability:(Reachability*)r
{
    NetworkStatus netStatus = [r currentReachabilityStatus];
 	BOOL connectionRequired= [r connectionRequired];
    
 	switch (netStatus) {
        case NotReachable:
            PJ_LOG(3,("", "Access Not Available.."));
            connectionRequired= NO;
            break;
        case ReachableViaWiFi:
            PJ_LOG(3,("", "Reachable WiFi.."));
            break;
        case ReachableViaWWAN:
            PJ_LOG(3,("", "Reachable WWAN.."));
            break;
    }
    
    if (connectionRequired) {
        PJ_LOG(3,("", "Connection Required"));
    }
}

@end
