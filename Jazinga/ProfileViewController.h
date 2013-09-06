//
//  ProfileViewController.h
//  Jazinga Softphone
//
//  Created by John Mah on 12-06-26.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GradientButton.h"
#import "LlamaSettings.h"

@interface ProfileViewController : UIViewController

@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) LlamaSettings *ls;
@property (strong, nonatomic) IBOutlet GradientButton *logoutButton;

- (IBAction)logout:(id)sender;

@end
