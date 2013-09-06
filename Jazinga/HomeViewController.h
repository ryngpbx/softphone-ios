//
//  HomeViewController.h
//  Jazinga Softphone
//
//  Created by John Mah on 12-06-26.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddressBookUI/AddressBookUI.h>
#import "EditingPersonViewController.h"

@interface HomeViewController : UITabBarController <ABPeoplePickerNavigationControllerDelegate, UINavigationControllerDelegate, ABNewPersonViewControllerDelegate, UITabBarControllerDelegate, ABPersonViewControllerDelegate, EditingPersonViewControllerDelegate>

@property (strong, nonatomic) ABPeoplePickerNavigationController *peoplePicker;
@property (nonatomic) BOOL initialLogin;
@property ABAddressBookRef addressBook;

@end
