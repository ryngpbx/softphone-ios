//
//  DialViewController.h
//
//  Created by John Mah on 12-05-10.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>

#import "EditingPersonViewController.h"
#import "GradientButton.h"
#include <pjsua-lib/pjsua.h>
#include "pjsua_app.h"
#include <pj/types.h>

@interface DialViewController : UIViewController <ABNewPersonViewControllerDelegate, UIActionSheetDelegate,ABPeoplePickerNavigationControllerDelegate,ABPersonViewControllerDelegate,EditingPersonViewControllerDelegate> {
    ABAddressBookRef addressBook;
}

@property (strong, nonatomic) IBOutlet UILabel *number;
@property (strong, nonatomic) IBOutlet UILabel *contactInfo;
@property (strong, nonatomic) IBOutlet UIButton *num1button;
@property (strong, nonatomic) IBOutlet UIButton *num2button;
@property (strong, nonatomic) IBOutlet UIButton *num3button;
@property (strong, nonatomic) IBOutlet UIButton *num4button;
@property (strong, nonatomic) IBOutlet UIButton *num5button;
@property (strong, nonatomic) IBOutlet UIButton *num6button;
@property (strong, nonatomic) IBOutlet UIButton *num7button;
@property (strong, nonatomic) IBOutlet UIButton *num8button;
@property (strong, nonatomic) IBOutlet UIButton *num9button;
@property (strong, nonatomic) IBOutlet UIButton *starButton;
@property (strong, nonatomic) IBOutlet UIButton *num0button;
@property (strong, nonatomic) IBOutlet UIButton *poundButton;
@property (strong, nonatomic) IBOutlet UIButton *addContactButton;
@property (strong, nonatomic) IBOutlet GradientButton *callButton;
@property (strong, nonatomic) IBOutlet UIButton *backspaceButton;
@property (strong, nonatomic) UIColor *dialpadBkColor;
@property (strong, nonatomic) UIColor *labelBkColor;
@property (strong, nonatomic) UIColor *dialpadSelectedBkColor;
@property (strong, nonatomic) NSDictionary *buttonToNumberDict;
@property (strong, nonatomic) NSDictionary *numberToDTMFSoundDict;
@property (strong, nonatomic) NSCharacterSet *accepted;
@property (strong, nonatomic) NSString* currentContactName;
@property BOOL shouldPlayFeedbackSounds;
@property (strong, nonatomic) NSTimer *zeroTimer;

- (IBAction)buttonTouchDown:(id)sender;
- (IBAction)buttonTouchUp:(id)sender;
- (IBAction)delButtonDown:(id)sender;
- (IBAction)delButtonUp:(id)sender;
- (IBAction)contactsButtonDown:(id)sender;
- (IBAction)contactsButtonUp:(id)sender;

- (IBAction)call:(id)sender;

@end
