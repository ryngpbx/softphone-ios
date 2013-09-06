//
//  ProfileViewController.m
//  Jazinga Softphone
//
//  Created by John Mah on 12-06-26.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import "ProfileViewController.h"
#import "AppDelegate.h"
#import "NSString+URLEncoding.h"
#import "NSDictionary_JSONExtensions.h"

@interface ProfileViewController ()

@end

@implementation ProfileViewController

@synthesize logoutButton;
@synthesize ls;
@synthesize tableView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

	ls = [[LlamaSettings alloc] initWithPlist:@"Jazinga.plist"];
	[ls setDelegate:self];
	[tableView setDataSource:ls];
	[tableView setDelegate:ls];

    [logoutButton useGreenConfirmStyle];
}

- (void)viewWillAppear:(BOOL)animated {
    // reload setting values (BUGBUG: doesn't seem to get called when app is opened from background)
    [ls loadSettingsFromSystem];
}

- (void)viewDidUnload
{
    [self setLogoutButton:nil];
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark IB actions

- (IBAction)logout:(id)sender {
    [self performSelectorOnMainThread:@selector(logout) withObject:nil waitUntilDone:NO];
}

-(void)logout {
    // logout the current user
    [[SIPAccountManager sharedAccountManager] logout];

    // bring up the login screen
    [self performSegueWithIdentifier:@"Login" sender:nil];
}

#pragma mark LlamaSettingsDelegate methods and support

- (BOOL)shouldCommitValueChange:(NSString*)key sender:(UIControl*)sender
{
    // handle out-of-office
    if ([key isEqualToString:@"out_of_office"]) {
        BOOL oof = ((UISwitch*)sender).on;

        // update the value in user defaults
        [[NSUserDefaults standardUserDefaults] setBool:oof forKey:@"out_of_office"];
        
        // then update on server
        [self performSelectorInBackground:@selector(updateProfile) withObject:nil];
    } else if ([key isEqualToString:@"mobile"]) {
        NSString *mobile = ((UITextField*)sender).text;
        
        // update the value in user defaults
        [[NSUserDefaults standardUserDefaults] setObject:mobile forKey:@"mobile"];
        
        // then update on server
        [self performSelectorInBackground:@selector(updateProfile) withObject:nil];
    }
    return YES;
}

- (void)settingsChanged:(LlamaSettings*)theSettings
{
	DebugLog( @"Delegate received 'settingsChanged' message" );
}

- (void) buttonPressed:(NSString*)buttonKey inSettings:(LlamaSettings*)ls
{
	DebugLog( @"Button Pressed: %@", buttonKey );
    if ([buttonKey isEqualToString:@"logout"]) {
        [self logout:self];
    } else if ([buttonKey isEqualToString:@"voicemail"]) {
        [[AppDelegate sharedAppDelegate] recordGreeting:@"unavail"
                                                caption:@"Record voicemail"];
    } else if ([buttonKey isEqualToString:@"name"]) {
        [[AppDelegate sharedAppDelegate] recordGreeting:@"greet"
                                                caption:@"Record greeting"];
    } else if ([buttonKey isEqualToString:@"temporary"]) {
        [[AppDelegate sharedAppDelegate] recordGreeting:@"temp"
                                                caption:@"Record temporary"];
    }
}

#pragma mark Profile update methods

- (void)updateProfile
{
#ifdef UPDATE_PROFILE
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    NSString *session_id = [ud objectForKey:@"session_id"];
    NSString *mobile = [ud objectForKey:@"mobile"];
    BOOL out_of_office = [ud boolForKey:@"out_of_office"];
                     
    NSString *postData = [NSString stringWithFormat:@"session_id=%@;mobile_number=%@;out_of_office=%@;request_version=%u;", 
                          session_id, 
                          [mobile urlEncodeUsingEncoding:NSUTF8StringEncoding], 
                          (out_of_office ? @"1" : @"0"),
                          SOFTPHONE_API_VERSION,
                          nil];
    NSData *myRequestData = [postData dataUsingEncoding:NSUTF8StringEncoding];
    
    // create request
    NSString *serverUrl = @JAZINGA_SETTINGS_UPDATE_URL;
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:serverUrl]]; 
    [request setHTTPMethod: @"POST"];
    [request setHTTPBody: myRequestData];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    // send request
    NSHTTPURLResponse* response = nil;  
    NSError* error = nil;  
    NSData *returnData = [NSURLConnection sendSynchronousRequest:request 
                                               returningResponse:&response 
                                                           error:&error];
    if (error != nil) {
        // TODO: report error
        return;
    };
    
    NSDictionary *json = [NSDictionary dictionaryWithJSONData:returnData error:&error];
    DebugLog(@"Update send result: %@", json);
    
    // check for request syntax error before checking request status
    NSString *err = [json valueForKey:@"error"];
    if ([err boolValue] == YES) {
        // TODO: report error
        return;
    }
#endif
}

@end
