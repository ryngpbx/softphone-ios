//
//  InboundViewController.h
//
//  Created by John Mah on 12-05-10.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>

#import "SIPCallDetails.h"
#import "GradientButton.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#include <pjsua-lib/pjsua.h>

enum {
    CallModeNormal = 0,
    CallModeDialer,
    CallModeTransfer,
    CallModeAdd,
};
typedef NSUInteger CallMode;

@interface InboundViewController : UIViewController <AVAudioSessionDelegate,UIActionSheetDelegate,ABPeoplePickerNavigationControllerDelegate>

@property (strong, nonatomic) IBOutlet UILabel *contactName;
@property (strong, nonatomic) IBOutlet UILabel *contactNumber;
@property (strong, nonatomic) IBOutlet GradientButton *acceptButton;
@property (strong, nonatomic) IBOutlet GradientButton *declineButton;
@property (strong, nonatomic) IBOutlet GradientButton *endButton;
@property (strong, nonatomic) IBOutlet GradientButton *muteButton;
@property (strong, nonatomic) IBOutlet GradientButton *holdButton;
@property (strong, nonatomic) IBOutlet GradientButton *transferButton;
@property (strong, nonatomic) IBOutlet GradientButton *addCallButton;
@property (strong, nonatomic) IBOutlet GradientButton *dialpadButton;
@property (strong, nonatomic) IBOutlet GradientButton *speakerButton;
@property (strong, nonatomic) IBOutlet GradientButton *dialpadEndButton;
@property (strong, nonatomic) IBOutlet GradientButton *hideDialpadButton;
@property (strong, nonatomic) IBOutlet GradientButton *transferAddButton;
@property (strong, nonatomic) IBOutlet GradientButton *cancelTransferAddButton;
@property (strong, nonatomic) IBOutlet UILabel *speakerLabel;

@property (strong, nonatomic) IBOutlet UIButton *num0button;
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
@property (strong, nonatomic) IBOutlet UIButton *poundButton;
@property (strong, nonatomic) IBOutlet UIButton *backspaceButton;

@property (strong, nonatomic) IBOutlet UIView *incallControlView;
@property (strong, nonatomic) IBOutlet UIView *incallDialpadView;
@property (strong, nonatomic) IBOutlet UIView *mainView;

@property (strong, nonatomic) UIActionSheet *transferSheet;
@property (strong, nonatomic) UIActionSheet *callOptionsSheet;

@property (strong, nonatomic) SIPCallDetails *callDetails;
@property (strong, nonatomic) SIPCallDetails *callWaitingDetails;

@property (nonatomic) BOOL useSpeaker;
@property (nonatomic, retain) NSTimer *timer;
@property (strong, nonatomic) NSDate *callStartTime;
@property (nonatomic) BOOL wentActive;
@property (nonatomic) BOOL clearDialpad;
@property (nonatomic) BOOL muted;
@property (nonatomic) BOOL bluetoothAvailable;

@property (strong, nonatomic) NSArray *inboundControls;
@property (strong, nonatomic) NSArray *incallControls;
@property (strong, nonatomic) NSArray *dialpadControls;

@property (strong, nonatomic) UIColor *dialpadBkColor;
@property (strong, nonatomic) UIColor *labelBkColor;
@property (strong, nonatomic) UIColor *dialpadSelectedBkColor;
@property (strong, nonatomic) NSDictionary *buttonToNumberDict;

@property (strong, nonatomic) IBOutlet UIView *audioControls;
@property (strong, nonatomic) IBOutlet GradientButton *builtInAudioButton;
@property (strong, nonatomic) IBOutlet GradientButton *speakerAudioButton;
@property (strong, nonatomic) IBOutlet GradientButton *bluetoothAudioButton;

@property CallMode callMode;

- (IBAction)accept:(id)sender;
- (IBAction)active:(id)sender;
- (IBAction)decline:(id)sender;
- (IBAction)end:(id)sender;
- (IBAction)mute:(id)sender;
- (IBAction)toggleSpeaker:(id)sender;
- (IBAction)addCall:(id)sender;
- (IBAction)transfer:(id)sender;
- (IBAction)hold:(id)sender;

- (IBAction)callOptions:(SIPCallDetails*)incomingCallDetails;
- (IBAction)endCallAndAnswer;
- (IBAction)ignoreCall;

- (IBAction)showDialpad:(id)sender;
- (IBAction)hideDialpad:(id)sender;

- (IBAction)buttonTouchDown:(id)sender;
- (IBAction)buttonTouchUp:(id)sender;

- (IBAction)cancel:(id)sender;

- (IBAction)cancelTransferAdd:(id)sender;
- (IBAction)transferAdd:(id)sender;

- (void)updateToggleSpeaker:(id)sender;

@end
