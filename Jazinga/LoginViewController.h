//
//  ViewController.h
//
//  Created by John Mah on 12-05-10.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GradientButton.h"
#import "JazingaLoginDelegate.h"

@interface LoginViewController : UIViewController <JazingaLoginDelegate> {
    IBOutlet GradientButton *signInButton;
    IBOutlet UITextField *username;
    IBOutlet UITextField *password;
    UIActivityIndicatorView *spinner;
}

@property (strong,nonatomic) UIActivityIndicatorView *spinner;
@property (strong,nonatomic) GradientButton *signInButton;
@property (nonatomic) BOOL autoLogin;
@property (nonatomic) BOOL initialLogin;

- (IBAction)signIn:(id)sender;

@end
