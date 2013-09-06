//
//  ViewController.m
//
//  Created by John Mah on 12-05-10.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import "LoginViewController.h"
#import "AppDelegate.h"

@interface LoginViewController ()

@end

@implementation LoginViewController

@synthesize spinner;
@synthesize signInButton;
@synthesize autoLogin;
@synthesize initialLogin;

- (void)viewDidLoad
{
    [super viewDidLoad];

    [signInButton useGreenConfirmStyle];
}

- (void)viewDidUnload
{
    username = nil;
    password = nil;
    
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated {
    [[UIApplication sharedApplication] setStatusBarHidden:YES 
                                            withAnimation:UIStatusBarAnimationSlide];
    [super viewWillAppear:animated];
    
    // if user has credentials saved use them
    NSString *storedUser = [[NSUserDefaults standardUserDefaults] valueForKey:@"email"];
    NSString *storedPwd = [[NSUserDefaults standardUserDefaults] valueForKey:@"password"];
    autoLogin = [[NSUserDefaults standardUserDefaults] boolForKey:@"auto_login"];

    if (storedUser != nil) {
        username.text = storedUser;
    }
    
    if (storedPwd != nil && [storedPwd length] > 0) {
        password.text = storedPwd;
    }

    // start login on new thread
    if (storedUser != nil && storedPwd != nil && autoLogin && initialLogin) {
        [self signIn:self];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [[UIApplication sharedApplication] setStatusBarHidden:NO 
                                            withAnimation:UIStatusBarAnimationSlide];
    [super viewWillAppear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (IBAction)signIn:(id)sender {
    // resign any text field focus so keyboard disappears
    [username resignFirstResponder];
    [password resignFirstResponder];
    
	// disable text fields until registration attempt completes
	[username setEnabled:NO];
	[password setEnabled:NO];
	
    // start spinner
    [self startSpinner];

    // hide sign-in button while we login
    [signInButton setHidden:YES];
    [signInButton setNeedsDisplay];
    
    // start signing in
    [self performSelector:@selector(doSignIn) withObject:nil afterDelay:1.0f];
}

-(void)doSignIn {
    // start authentication process
    [[SIPAccountManager sharedAccountManager] authenticateUser:[username text]
                                         withPassword:[password text] 
                                             delegate:self];
}

#pragma mark JazingaLoginDelegate methods

-(void)authenticated {
    // update user/pass in defaults
    [[NSUserDefaults standardUserDefaults] setValue:[username text] forKey:@"email"];
    [[NSUserDefaults standardUserDefaults] setValue:[password text] forKey:@"password"];

    // dismiss the login screen
	dispatch_async(dispatch_get_main_queue(), ^{
		[self dismissViewControllerAnimated:YES completion:nil];
    });

    //[self dismissViewControllerAnimated:YES completion:nil];
}

-(void)authenticationFailedWithMessage:(NSString*)message {
	dispatch_async(dispatch_get_main_queue(), ^{
		[[AppDelegate sharedAppDelegate] showAlert:@"Cannot Login"
									   withMessage:message];
		
		// show sign-in button for later attempt
		[signInButton setHidden:NO];
		
		// re-enabled text fields
		[username setEnabled:YES];
		[password setEnabled:YES];
	});
}

-(void)didStartAuthentication {
}

-(void)didFinishAuthentication {
	dispatch_async(dispatch_get_main_queue(), ^{
		// stop spinner
		[self stopSpinner];
		
		// hide sign-in button while we login
		[signInButton setHidden:NO];
		[signInButton setNeedsDisplay];
	});
}

-(void)startSpinner {
    // create busy spinner
    if (spinner != nil) return;
    
    spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.center = CGPointMake(self.view.frame.size.width/2, self.view.frame.size.height/2);
    [self.view addSubview: spinner];
    [spinner startAnimating];
}

-(void)stopSpinner {
    // hide busy spinner
    [spinner stopAnimating];
    [spinner removeFromSuperview];
    spinner = nil;
}

@end

