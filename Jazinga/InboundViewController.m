//
//  InboundViewController.m
//
//  Created by John Mah on 12-05-10.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import "InboundViewController.h"
#import "AppDelegate.h"
#import "PhoneNumber.h"
#import "SIPAudioManager.h"

#define VIEW_LINGER_DURATION    1.5f

@interface InboundViewController ()

@end

@implementation InboundViewController

@synthesize contactName;
@synthesize contactNumber;
@synthesize acceptButton;
@synthesize declineButton;
@synthesize endButton;
@synthesize muteButton;
@synthesize holdButton;
@synthesize transferButton;
@synthesize addCallButton;
@synthesize dialpadButton;
@synthesize speakerButton;
@synthesize incallControlView;
@synthesize incallDialpadView;
@synthesize mainView;
@synthesize dialpadEndButton;
@synthesize hideDialpadButton;
@synthesize transferAddButton;
@synthesize cancelTransferAddButton;

@synthesize num0button;
@synthesize num1button;
@synthesize num2button;
@synthesize num3button;
@synthesize num4button;
@synthesize num5button;
@synthesize num6button;
@synthesize num7button;
@synthesize num8button;
@synthesize num9button;
@synthesize starButton;
@synthesize poundButton;
@synthesize backspaceButton;
@synthesize speakerLabel;

@synthesize inboundControls;
@synthesize incallControls;
@synthesize dialpadControls;

@synthesize transferSheet;
@synthesize callOptionsSheet;

@synthesize callDetails;
@synthesize callWaitingDetails;
@synthesize useSpeaker;
@synthesize timer;
@synthesize callStartTime;
@synthesize wentActive;
@synthesize clearDialpad;
@synthesize muted;

@synthesize dialpadBkColor;
@synthesize dialpadSelectedBkColor;
@synthesize labelBkColor;
@synthesize buttonToNumberDict;
@synthesize callMode;

@synthesize audioControls;
@synthesize builtInAudioButton;
@synthesize speakerAudioButton;
@synthesize bluetoothAudioButton;

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
    
    self.buttonToNumberDict = [NSDictionary dictionaryWithObjectsAndKeys:                                
                               @"1", [NSValue valueWithNonretainedObject:num1button],
                               @"2", [NSValue valueWithNonretainedObject:num2button],
                               @"3", [NSValue valueWithNonretainedObject:num3button],
                               @"4", [NSValue valueWithNonretainedObject:num4button],
                               @"5", [NSValue valueWithNonretainedObject:num5button],
                               @"6", [NSValue valueWithNonretainedObject:num6button],
                               @"7", [NSValue valueWithNonretainedObject:num7button],
                               @"8", [NSValue valueWithNonretainedObject:num8button],
                               @"9", [NSValue valueWithNonretainedObject:num9button],
                               @"0", [NSValue valueWithNonretainedObject:num0button],
                               @"*", [NSValue valueWithNonretainedObject:starButton],
                               @"#", [NSValue valueWithNonretainedObject:poundButton],
                               nil];
    
    // setup our colors
    self.dialpadBkColor = [UIColor colorWithRed:12.0f/255.0f 
                                          green:14.0f/255.0f 
                                           blue:33.0f/255.0f 
                                          alpha:1.0f];
    self.dialpadSelectedBkColor = [UIColor colorWithRed:46.0f/255.0f 
                                                  green:90.0f/255.0f 
                                                   blue:214.0f/255.0f 
                                                  alpha:1.0f];
    self.labelBkColor = [UIColor colorWithRed:26.0f/255.0f
                                        green:52.0f/255.0f
                                         blue:100.0f/255.0f
                                        alpha:1.0f];

    self.useSpeaker = [[NSUserDefaults standardUserDefaults] boolForKey:@"default_speaker"];
    self.wentActive = NO;
    self.clearDialpad = NO;
    self.muted = NO;

    // check if bluetooth is available
    self.bluetoothAvailable = [[SIPAudioManager sharedSIPAudioManager] bluetoothAvailable];

    // show/hide call disconnection buttons
    inboundControls = [NSArray arrayWithObjects:acceptButton, declineButton,nil];
    incallControls = [NSArray arrayWithObjects:endButton, nil];
    dialpadControls = [NSArray arrayWithObjects:dialpadEndButton, hideDialpadButton,nil];    
    
    [acceptButton useGreenConfirmStyle];
    [declineButton useRedDeleteStyle];
    [endButton useRedDeleteStyle];
    [dialpadEndButton useRedDeleteStyle];
    [hideDialpadButton useBlackStyle];
    [cancelTransferAddButton useRedDeleteStyle];
    [transferAddButton useGreenConfirmStyle];
    
    [muteButton useBlackActionSheetStyle];
    [muteButton setBorderStyle:BorderRadiusDrawTopLeft];
    [holdButton useBlackActionSheetStyle];
    [holdButton setBorderStyle:BorderRadiusDrawBottomRight];
    [addCallButton useBlackActionSheetStyle];    
    [addCallButton setBorderStyle:BorderRadiusDrawBottomLeft];
    [speakerButton useBlackActionSheetStyle];
    [speakerButton setBorderStyle:BorderRadiusDrawTopRight];
    [dialpadButton useBlackActionSheetStyle];
    [dialpadButton setBorderStyle:BorderRadiusDrawNone];
    [transferButton useBlackActionSheetStyle];
    [transferButton setBorderStyle:BorderRadiusDrawNone];

	[builtInAudioButton useBlackActionSheetStyle];
	[speakerAudioButton useBlackActionSheetStyle];
	[bluetoothAudioButton useBlackActionSheetStyle];
	
    BOOL inbound = callDetails.type == CallTypeInbound;
    acceptButton.hidden = !inbound;
    declineButton.hidden = !inbound;
    endButton.hidden = inbound;
    dialpadEndButton.hidden = YES;
    hideDialpadButton.hidden = YES;

    // get info about call
    contactName.text = [callDetails callerDisplay];

    if (inbound == YES) {
        contactNumber.text = @"incoming...";
    } else {
        contactNumber.text = @"calling...";

        // setup loudspeaker if output
		if (useSpeaker == YES) {
			[self speaker:self];
		} else if (self.bluetoothAvailable == YES) {
			[self bluetooth:self];
		} else {
			[self builtInAudio:self];
		}
        
        // show control pad on outgoing calls
        [incallControlView setHidden:NO];
    }
    
    // set toggle state for speaker buttons
	if (self.bluetoothAvailable == NO) {
	    [speakerButton setHighlighted:useSpeaker];
    } else /*(self.bluetoothAvailable == YES)*/ {
        speakerLabel.text = @"audio";
    }
	
    // record call start time
    self.callStartTime = [NSDate date];

    // disable Siri proximity detection
    [UIDevice currentDevice].proximityMonitoringEnabled = YES;
}

- (void)viewDidUnload
{
    [self setContactName:nil];
    [self setContactNumber:nil];
    [self setMuteButton:nil];
    [self setHoldButton:nil];
    [self setTransferButton:nil];
    [self setAddCallButton:nil];
    [self setDialpadButton:nil];
    [self setEndButton:nil];
    [self setSpeakerButton:nil];
    [self setIncallControlView:nil];
    [self setIncallDialpadView:nil];
    
    [self setTransferSheet:nil];
    [self setCallOptionsSheet:nil];

    [self.timer invalidate];

    [self setDialpadEndButton:nil];
    [self setHideDialpadButton:nil];
    [self setMainView:nil];
    
    [self setTransferAddButton:nil];
    [self setCancelTransferAddButton:nil];
    [self setBackspaceButton:nil];

    [self setSpeakerLabel:nil];
    [self setBuiltInAudioButton:nil];
    [self setSpeakerAudioButton:nil];
    [self setBluetoothAudioButton:nil];
    [self setAudioControls:nil];
    [super viewDidUnload];
}

- (void)viewDidAppear:(BOOL)animated {
    // cancel the dialog if we don't have a valid call
    pjsua_call_id ci = callDetails.callID;
    if (pjsua_call_is_active(ci) != PJ_TRUE) {
        contactNumber.text = @"call failed";
        [self cancel:[NSNumber numberWithInteger:callDetails.callID]];
    }
    
    // start ring just in case
    if (callDetails.type == CallTypeInbound) {
        // start local ring if necessary
        ring_start(ci);
        
        // play ring on speaker
        [self useSpeaker:YES];
    }

    // allow bluetooth devices to control call
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
}

- (void)viewDidDisappear:(BOOL)animated {
    // turn speaker back on (so ringing, etc. are on speaker)
    [self useSpeaker:YES];
    
    // re-enable Siri proximity detection
    [UIDevice currentDevice].proximityMonitoringEnabled = NO;
    
    // allow bluetooth devices to control call
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)updateTimeTimerFired:(id)sender {
    // get current time
    NSTimeInterval callTimeSoFar = -[callStartTime timeIntervalSinceNow];
    
    // interpret seconds to hh:mm:ss format
    NSUInteger hours = callTimeSoFar / 3600;
    NSUInteger mins = ((NSUInteger)callTimeSoFar - (hours * 3600)) / 60;
    NSUInteger secs = ((NSUInteger)callTimeSoFar - (hours * 3600) - (mins * 60));
    
    // set the call duration text
    contactNumber.text = [NSString stringWithFormat:@"%02u:%02u:%02u", 
                          hours, mins, secs, nil];
}

- (IBAction)accept:(id)sender {
    // answer the call
    AppDelegate *delegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    [delegate answer_call:callDetails.callID];
}

- (IBAction)active:(id)sender {
    // sender is the call id of the active call
    pjsua_call_id ci = [sender intValue];
    
    // if call that went active is NOT main call then add to list of added calls
    if (ci != callDetails.callID) return;

    // show/hide call disconnection buttons
    [acceptButton setHidden:YES];
    [declineButton setHidden:YES];
    [endButton setHidden:NO];
    
    // call was active at some point
    self.wentActive = YES;
    
    // unhide Inbound controls
    [incallControlView setHidden:NO];
    [incallDialpadView setHidden:YES];
    
    // clear field for active call
    [contactNumber setText:@""];
    
    // update call start time
    self.callStartTime = [NSDate date];

    // create timer to update call duration
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 
                                                  target:self 
                                                selector:@selector(updateTimeTimerFired:) 
                                                userInfo:nil 
                                                 repeats:YES];
    
    // mute the call upon going active
    [self configure];
}


- (IBAction)cancel:(id)sender {
    // sender is call_id of cancelled call
    pjsua_call_id ci = [sender intValue];
    
    // if disconnected call is the call waiting call, handle separately
    if (callWaitingDetails != nil && ci == callWaitingDetails.callID) {
        [self cancelCallWaiting:ci];
        return;
    }

    // if cancelled call is main call and we still have outstanding calls, don't close window
    unsigned int callsOutstanding = pjsua_call_get_count();
    if (callsOutstanding > 1) {
        return;
    }
    
    // determine if this was a missed call
    if (wentActive == NO && callDetails.type == CallTypeInbound) {
        contactNumber.text = @"call missed";
        callDetails.type = CallTypeMissed;
    }
    
    // write call log entry
    AppDelegate *delegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    [delegate addCallLogEntry:callDetails
                        start:callStartTime
                          end:[NSDate date]];
    
    // kill call timer (if running)
    [self.timer invalidate];
    
    // close this screen and return to previous
    [self dismissWithMessage:nil];
}

- (IBAction)cancelCallWaiting:(pjsua_call_id)callID {
    // trivial error check
    if (callWaitingDetails == nil) return;
    
    // determine if this was a missed call
    if (callWaitingDetails.type == CallTypeInbound) {
        callWaitingDetails.type = CallTypeMissed;
    }
    
    // write call log entry
    AppDelegate *delegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    [delegate addCallLogEntry:callWaitingDetails
                        start:[NSDate date]
                          end:[NSDate date]];
    
    // dismiss the options sheet
    [self.callOptionsSheet dismissWithClickedButtonIndex:0 animated:YES];
    
    // clear any outstanding call waiting details
    callOptionsSheet = nil;
    callWaitingDetails = nil;
}

- (void)configure {
    // don't do anything until call is active
    if (wentActive == NO) return;
    
    // setup muting, if needed
    pjsua_call_info callInfo;
    memset(&callInfo, 0, sizeof(callInfo));
    pj_status_t status = pjsua_call_get_info(callDetails.callID, &callInfo);
    if (status != PJ_SUCCESS) return;

    if (muted == YES) {
        pjsua_conf_disconnect(0, callInfo.conf_slot);
    } else {
        pjsua_conf_connect(0, callInfo.conf_slot);
    }
    
    // if speaker is enabled, use it
	if (useSpeaker == YES && self.bluetoothAvailable == NO) {
		[self speaker:self];
	} else if (self.bluetoothAvailable == YES) {
		[self bluetooth:self];
	} else {
		[self builtInAudio:self];
	}
}

- (void)dismissWithMessage:(NSString*)message
{
    // update the message so user knows what is going on
    if (message != nil)
        [contactNumber setText:message];
    
    // delay removing the screen a few moments so user can see message
    [self performSelector:@selector(close)
               withObject:nil
               afterDelay:VIEW_LINGER_DURATION];
}

- (void)close
{
    // cancel any opened action sheets
    [self.transferSheet dismissWithClickedButtonIndex:transferSheet.cancelButtonIndex
                                     animated:NO];
    [self.callOptionsSheet dismissWithClickedButtonIndex:callOptionsSheet.cancelButtonIndex
                                                animated:NO];
    
    // close screen
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)decline:(id)sender {
    // mark as active so call log doesn't mark it as missed
    wentActive = YES;

    // hangup the call
    AppDelegate *delegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    [delegate decline_call:callDetails.callID];

    // close this screen and return to previous
    [self dismissWithMessage:@"call declined"];
}

- (IBAction)end:(id)sender {
    // hangup the call
    AppDelegate *delegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    [delegate decline_call:callDetails.callID];

    // update close message
    contactNumber.text = @"call ended";

    // close this screen and return to previous
    if (wentActive == NO || pjsua_call_get_count() == 0) {
        // close this screen and return to previous
        [self dismissWithMessage:nil];
    }
}

- (IBAction)showTransferAdd:(id)sender
{
    [UIView transitionWithView:mainView
                      duration:0.75f
                       options:UIViewAnimationOptionTransitionFlipFromLeft | UIViewAnimationOptionShowHideTransitionViews | UIViewAnimationOptionAllowAnimatedContent
                    animations:^{
                        [incallControlView setHidden:YES];
                        [audioControls setHidden:YES];
                        [incallDialpadView setHidden:NO];
                    }
                    completion:nil];
    
    [transferAddButton setHidden:NO];
    [cancelTransferAddButton setHidden:NO];
    [backspaceButton setHidden:NO];
    [endButton setHidden:YES];

    // get size of backspace button
    NSUInteger bsButtonWidth = self.backspaceButton.frame.size.width;

    // resize the contactNumber to all
    CGRect nameRect = self.contactName.frame;
    nameRect.size.width -= bsButtonWidth;
    self.contactName.frame = nameRect;
    self.contactName.text = @"";

    self.clearDialpad = YES;
    self.contactName.lineBreakMode = UILineBreakModeHeadTruncation;
}

- (void)hideTransferAddButtons:(id)sender
{
    [UIView transitionWithView:mainView
                      duration:0.75f
                       options:UIViewAnimationOptionTransitionFlipFromRight | UIViewAnimationOptionShowHideTransitionViews | UIViewAnimationOptionAllowAnimatedContent
                    animations:^{
                        [incallControlView setHidden:NO];
                        [audioControls setHidden:YES];
                        [incallDialpadView setHidden:YES];
                    }
                    completion:nil];
    
    [transferAddButton setHidden:YES];
    [cancelTransferAddButton setHidden:YES];
    [backspaceButton setHidden:YES];
    [endButton setHidden:NO];
    
    // get size of backspace button
    NSUInteger bsButtonWidth = self.backspaceButton.frame.size.width;
    
    // resize the contactNumber to all
    CGRect nameRect = self.contactName.frame;
    nameRect.size.width += bsButtonWidth;
    self.contactName.frame = nameRect;
    
    // configure contactname field for in-call operation
    self.clearDialpad = NO;
    self.contactName.lineBreakMode = UILineBreakModeTailTruncation;
    
    // restore contact name
    self.contactName.text = [callDetails callerDisplay];
}

- (IBAction)cancelTransferAdd:(id)sender
{
    [self hideTransferAddButtons:sender];
    callMode = CallModeNormal;
}

- (void)performTransferOrAdd:(NSString*)number
{
    // now add the favourite
    if (callMode == CallModeTransfer) {
        if ([number length] > 0) {
            [[AppDelegate sharedAppDelegate] transfer:callDetails.callID
                                               number:number];
            contactNumber.text = @"call transferred";

            // kill call duration timer for now
            [self.timer invalidate];
        }
    } else if (callMode == CallModeAdd) {
        [[AppDelegate sharedAppDelegate] add:callDetails.callID
                                      number:number];
        contactNumber.text = @"caller added";
    }
}

- (IBAction)transferAdd:(id)sender {
    // get number entered so far
    NSString *number = [contactName text];
    [self performTransferOrAdd:number];

    [self hideTransferAddButtons:sender];

    callMode = CallModeNormal;
}

- (IBAction)mute:(id)sender {
    muted = !muted;
    [self configure];
    
    [self performSelectorOnMainThread:@selector(updateMute:) 
                           withObject:[NSNumber numberWithBool:muted] 
                        waitUntilDone:NO];
}

- (void)updateMute:(id)sender {
    [muteButton setHighlighted:[sender boolValue]];
    [muteButton setNeedsDisplay];
}

#pragma mark - Audio support

- (IBAction)toggleSpeaker:(id)sender {
	// don't need to handle this if bluetooth is available
	if (self.bluetoothAvailable == YES) return;

    // override the output audio route with speaker
    useSpeaker = !useSpeaker;
    [self useSpeaker:useSpeaker];
    [self performSelectorOnMainThread:@selector(updateToggleSpeaker:)
                           withObject:[NSNumber numberWithBool:useSpeaker]
                        waitUntilDone:NO];
}

- (void)updateToggleSpeaker:(id)sender {
    BOOL speaker = [sender intValue];
    [speakerButton setHighlighted:speaker];
    [speakerButton setNeedsDisplay];
}

- (IBAction)toggleAudio:(id)sender {
	// only do this if we have bluetooth device paired
	if (self.bluetoothAvailable == NO) return;
	
	[UIView transitionWithView:mainView
                      duration:0.75f
                       options:UIViewAnimationOptionTransitionFlipFromLeft | UIViewAnimationOptionShowHideTransitionViews | UIViewAnimationOptionAllowAnimatedContent
                    animations:^{
                        [incallControlView setHidden:YES];
                        [incallDialpadView setHidden:YES];
                        [audioControls setHidden:NO];
                    }
                    completion:nil];
	
	[dialpadEndButton setHidden:NO];
    [hideDialpadButton setHidden:NO];
    [endButton setHidden:YES];

    [speakerButton setHighlighted:NO];
    [speakerButton setNeedsDisplay];
	
	[hideDialpadButton setTitle:@"Hide Audio" forState:UIControlStateNormal];
}

- (void)useSpeaker:(BOOL)on
{
	if (useSpeaker == YES) {
		[self speaker:self];
	} else {
		[self builtInAudio:self];
	}
}

#if 0
- (void)speaker:(BOOL)on {
    pjmedia_aud_dev_route route = (on == YES ? PJMEDIA_AUD_DEV_ROUTE_LOUDSPEAKER : PJMEDIA_AUD_DEV_ROUTE_DEFAULT);
    pjsua_snd_set_setting(PJMEDIA_AUD_DEV_CAP_OUTPUT_ROUTE, &route, PJ_TRUE);
}
#endif

- (IBAction)builtInAudio:(id)sender
{
	dispatch_async(dispatch_get_main_queue(), ^{
		pjmedia_aud_dev_route route = PJMEDIA_AUD_DEV_ROUTE_DEFAULT;
		pjsua_snd_set_setting(PJMEDIA_AUD_DEV_CAP_INPUT_ROUTE, &route, PJ_TRUE);
		route = PJMEDIA_AUD_DEV_ROUTE_DEFAULT;
		pjsua_snd_set_setting(PJMEDIA_AUD_DEV_CAP_OUTPUT_ROUTE, &route, PJ_TRUE);

		[self updateAudioButtons:route];
	});
}

- (IBAction)speaker:(id)sender
{
	dispatch_async(dispatch_get_main_queue(), ^{
		pjmedia_aud_dev_route route = PJMEDIA_AUD_DEV_ROUTE_LOUDSPEAKER;
		pjsua_snd_set_setting(PJMEDIA_AUD_DEV_CAP_INPUT_ROUTE, &route, PJ_TRUE);
		route = PJMEDIA_AUD_DEV_ROUTE_LOUDSPEAKER;
		pjsua_snd_set_setting(PJMEDIA_AUD_DEV_CAP_OUTPUT_ROUTE, &route, PJ_TRUE);
		
		[self updateAudioButtons:route];
	});
}

- (IBAction)bluetooth:(id)sender
{
	dispatch_async(dispatch_get_main_queue(), ^{
		pjmedia_aud_dev_route route = PJMEDIA_AUD_DEV_ROUTE_BLUETOOTH;
		pjsua_snd_set_setting(PJMEDIA_AUD_DEV_CAP_INPUT_ROUTE, &route, PJ_TRUE);
		route = PJMEDIA_AUD_DEV_ROUTE_BLUETOOTH;
		pjsua_snd_set_setting(PJMEDIA_AUD_DEV_CAP_OUTPUT_ROUTE, &route, PJ_TRUE);
		
		[self updateAudioButtons:route];
	});
}

- (void)updateAudioButtons:(pjmedia_aud_dev_route)route
{
	[self.builtInAudioButton setImage:nil forState:UIControlStateNormal];
	[self.speakerAudioButton setImage:nil forState:UIControlStateNormal];
	[self.bluetoothAudioButton setImage:nil forState:UIControlStateNormal];

	UIButton* button = nil;
	switch (route) {
		case PJMEDIA_AUD_DEV_ROUTE_EARPIECE:
		case PJMEDIA_AUD_DEV_ROUTE_DEFAULT:
			button = self.builtInAudioButton;
			break;
			
		case PJMEDIA_AUD_DEV_ROUTE_LOUDSPEAKER:
			button = self.speakerAudioButton;
			break;
			
		case PJMEDIA_AUD_DEV_ROUTE_BLUETOOTH:
			button = self.bluetoothAudioButton;
			break;
	}

	[button setImage:[UIImage imageNamed:@"audio"] forState:UIControlStateNormal];

	[self.builtInAudioButton setNeedsDisplay];
	[self.speakerAudioButton setNeedsDisplay];
	[self.bluetoothAudioButton setNeedsDisplay];
}

#pragma mark - Add/Transfer support

- (IBAction)addCall:(id)sender {
    callMode = CallModeAdd;

    // set button text to "Add"
    [transferAddButton setTitle:@" Add" forState:UIControlStateNormal];
    [transferAddButton setImage:[UIImage imageNamed:@"addcall.png"] forState:UIControlStateNormal];

    // present options to add or edit
    transferSheet = [[UIActionSheet alloc] initWithTitle:@"Add"
                                        delegate:self
                               cancelButtonTitle:@"Cancel"
                          destructiveButtonTitle:nil
                               otherButtonTitles:@"Enter Number...", @"Choose Contact...", nil];
    [transferSheet showInView:self.view];
}

- (IBAction)transfer:(id)sender {
    callMode = CallModeTransfer;

    // set button text to "Transfer"
    [transferAddButton setTitle:@" Transfer" forState:UIControlStateNormal];
    [transferAddButton setImage:[UIImage imageNamed:@"transfer.png"] forState:UIControlStateNormal];
    
    // present options to add or edit
    transferSheet = [[UIActionSheet alloc] initWithTitle:@"Transfer Call"
                                        delegate:self
                               cancelButtonTitle:@"Cancel"
                          destructiveButtonTitle:nil
                               otherButtonTitles:@"Enter Number...", @"Choose Contact...", nil];
    [transferSheet showInView:self.view];
}

- (IBAction)callOptions:(SIPCallDetails*)incomingCallDetails {
    // play vibrate to let user know
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);

    // save details about incoming call
    self.callWaitingDetails = incomingCallDetails;

    // present options to add or edit
    callOptionsSheet = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:@"Incoming call from %@", incomingCallDetails.callerDisplay]
                                                   delegate:self
                                          cancelButtonTitle:nil
                                     destructiveButtonTitle:nil
                                          otherButtonTitles:@"Ignore",
                                                            @"Decline",
                                                            @"Merge Calls",
                                                            @"End Call + Answer", nil];
    callOptionsSheet.destructiveButtonIndex = 3;
    [callOptionsSheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet
    clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // trivial error check
    if (actionSheet == nil) return;
    
    // handle action sheet choices for transfer
    if (actionSheet == transferSheet) {
        if (buttonIndex == 0) {
            // handle enter contact #
            [self showTransferAdd:nil];
        } else if (buttonIndex == 1) {
            // from a existing contact, first pick a contact
            ABPeoplePickerNavigationController *picker = [[ABPeoplePickerNavigationController alloc] init];
            picker.peoplePickerDelegate = self;
            
            // chained completion uses uses selection to open new person editor
            [self presentViewController:picker animated:YES completion:nil];
        }

        self.transferSheet = nil;
    } else if (actionSheet == callOptionsSheet) {
        if (buttonIndex == 0) {
            [self ignoreCall];
        } else if (buttonIndex == 1) {
            [self declineCallWaiting];
        } else if (buttonIndex == 2) {
            [self mergeCalls];
        } else if (buttonIndex == 3) {
            [self endCallAndAnswer];
        }
        
        self.callOptionsSheet = nil;
        self.callWaitingDetails = nil;
    }
}

- (IBAction)ignoreCall {
    // trivial error check
    if (self.callWaitingDetails == nil) return;
    
    // cancel ringing on incoming call
    ring_stop(self.callWaitingDetails.callID);
}

- (IBAction)declineCallWaiting {
    // hangup existing call
    pjsua_call_hangup(self.callWaitingDetails.callID, 603, NULL, NULL);
}

- (IBAction)mergeCalls {
    // trivial error check
    if (self.callWaitingDetails == nil) return;
    
    // answer the incoming call (autoconf will add to current call)
    self.callWaitingDetails.type = CallTypeConference;
    [[AppDelegate sharedAppDelegate] answer_call:self.callWaitingDetails.callID];
}

- (IBAction)holdCallAndAnswer {
    // BUGBUG: Unsupported at the moment
    /*
    // trivial error check
    if (self.callWaitingDetails == nil) return;

    // save info about current call
    self.callParked = self.callDetails;
    
    // park the current call
    [self hold:nil];

    // answer the incoming call
    [[AppDelegate sharedAppDelegate] answer_call:self.callWaitingDetails.callID];
    */
}

- (IBAction)endCallAndAnswer {
    // trivial error check
    if (self.callWaitingDetails == nil) return;
    
    // hangup existing call
    pjsua_call_hangup(self.callDetails.callID, 487, NULL, NULL);
    
    // answer the incoming call
    [[AppDelegate sharedAppDelegate] answer_call:self.callWaitingDetails.callID];
    
    // swap details
    self.callDetails = self.callWaitingDetails;
    
    // update UI
    [self hideDialpad:nil];
}

- (IBAction)hold:(id)sender {
    // trivial error checking
    if (callDetails.callID == -1) return;

    struct pjsua_call_info info;
    memset(&info, 0, sizeof(info));
    pj_status_t status = pjsua_call_get_info(callDetails.callID, &info);

    if (status == PJ_SUCCESS && info.media_status == PJSUA_CALL_MEDIA_ACTIVE) {
        pjsua_call_set_hold(callDetails.callID, NULL);
    } else if (status == PJ_SUCCESS && info.media_status == PJSUA_CALL_MEDIA_LOCAL_HOLD) {
        pjsua_call_reinvite(callDetails.callID, PJSUA_CALL_UNHOLD, NULL);
    }
}

- (IBAction)showDialpad:(id)sender {
    [UIView transitionWithView:mainView 
                      duration:0.75f 
                       options:UIViewAnimationOptionTransitionFlipFromLeft | UIViewAnimationOptionShowHideTransitionViews | UIViewAnimationOptionAllowAnimatedContent
                    animations:^{
                        [incallControlView setHidden:YES];
						[audioControls setHidden:YES];
                        [incallDialpadView setHidden:NO];
                    }
                    completion:nil];

    [dialpadEndButton setHidden:NO];
    [hideDialpadButton setHidden:NO];
    [endButton setHidden:YES];

	[hideDialpadButton setTitle:@"Hide Dialpad" forState:UIControlStateNormal];

    // configure contactname field for dialpad operation
    self.clearDialpad = YES;
    self.contactName.lineBreakMode = UILineBreakModeHeadTruncation;

    callMode = CallModeDialer;
}

- (IBAction)hideDialpad:(id)sender {
    [UIView transitionWithView:mainView 
                      duration:0.75f 
                       options:UIViewAnimationOptionTransitionFlipFromRight | UIViewAnimationOptionShowHideTransitionViews | UIViewAnimationOptionAllowAnimatedContent
                    animations:^{
                        [incallDialpadView setHidden:YES];
						[audioControls setHidden:YES];
                        [incallControlView setHidden:NO];
                    }
                    completion:nil];

    [dialpadEndButton setHidden:YES];
    [hideDialpadButton setHidden:YES];
    [endButton setHidden:NO];
    
    // configure contactname field for in-call operation
    self.clearDialpad = NO;
    self.contactName.lineBreakMode = UILineBreakModeTailTruncation;
    
    // restore contact name
    self.contactName.text = [callDetails callerDisplay];
    
    callMode = CallModeNormal;
}

- (IBAction)buttonTouchDown:(id)sender {
    // get current text
    NSString *currentText = [contactName text];
    
    // if backspace button delete last char instead of adding a new one
    if (sender == backspaceButton) {
        NSUInteger len = [currentText length];
        if (currentText != nil && len > 0) {
            // update the number
            contactName.text = [currentText substringToIndex:len-1];
        }
        return;
    }

    // highlight the button
    [sender setBackgroundColor:dialpadSelectedBkColor];

    // if first key pressed in dialpad, reconfigure the contact number text box
    if (clearDialpad == YES) {
        currentText = @"";
        clearDialpad = NO;
    }

    // append button value to label
    NSString *textToAppend = nil;
    textToAppend = [buttonToNumberDict objectForKey:[NSValue valueWithNonretainedObject:sender]];
    if (textToAppend != nil) {
        // update the label text
        contactName.text = [currentText stringByAppendingString:textToAppend];

        // create send digit loop via DTMF over RFC2833
        if (callMode == CallModeDialer) {
            [[AppDelegate sharedAppDelegate] send:callDetails.callID 
                                            digit:[textToAppend characterAtIndex:0] 
                                         duration:0.7f];
        }
    }
}

- (IBAction)buttonTouchUp:(id)sender {
    // unhighlight the button
    [sender setBackgroundColor:dialpadBkColor];

    NSString *textToAppend = [buttonToNumberDict objectForKey:[NSValue valueWithNonretainedObject:sender]];
    if (textToAppend != nil && callMode == CallModeDialer) {
        // stop digit via DTMF
        [[AppDelegate sharedAppDelegate] stop_dtmf:callDetails.callID 
                                             digit:[textToAppend characterAtIndex:0]];
    }
}

- (void)dtmfTimerFired:(NSTimer*)theTimer {
    NSString *textToSend = [theTimer userInfo];
    [[AppDelegate sharedAppDelegate] send:callDetails.callID 
                                    digit:[textToSend characterAtIndex:0] 
                                 duration:0.7f];
}

- (IBAction)updateHoldStatus:(id)sender {
    // trivial error checking
    if (callDetails.callID == -1) return;

    struct pjsua_call_info info;
    memset(&info, 0, sizeof(info));
    pj_status_t status = pjsua_call_get_info(callDetails.callID, &info);

    if (status == PJ_SUCCESS && info.media_status == PJSUA_CALL_MEDIA_LOCAL_HOLD) {
        [holdButton setHighlighted:YES];
        [holdButton setNeedsDisplay];
    } else {
        [holdButton setHighlighted:NO];
        [holdButton setNeedsDisplay];
    }
}

#pragma mark ABPeoplePickerNavigationControllerDelegate methods

- (void)peoplePickerNavigationControllerDidCancel:
(ABPeoplePickerNavigationController *)peoplePicker
{
    [self dismissModalViewControllerAnimated:YES];
}

- (BOOL)peoplePickerNavigationController:
(ABPeoplePickerNavigationController *)peoplePicker
      shouldContinueAfterSelectingPerson:(ABRecordRef)person {
    return YES;
}

- (BOOL)peoplePickerNavigationController:
(ABPeoplePickerNavigationController *)peoplePicker
      shouldContinueAfterSelectingPerson:(ABRecordRef)person
                                property:(ABPropertyID)property
                              identifier:(ABMultiValueIdentifier)identifier
{
    // don't initiate normal phone calls if phone #, use SIP instead
    if (property == kABPersonPhoneProperty) {
        // perform the call transfer or caller add
        NSString *number = [PhoneNumber numberFrom:ABRecordGetRecordID(person)
                                          property:identifier];
        [self performTransferOrAdd:number];
        
        // dismiss picker
        [peoplePicker dismissViewControllerAnimated:YES completion:nil];
    }
    return YES;
}

#pragma mark - remote control events for bluetooth devices

- (void)remoteControlReceivedWithEvent:(UIEvent*)event
{
	if (event == nil || event.type != UIEventTypeRemoteControl) return;
	
	if (event.subtype == UIEventSubtypeRemoteControlStop) {
		// hangup call
		[self end:self];
	} else if (event.subtype == UIEventSubtypeRemoteControlPause) {
		// put call on hold
		[self hold:self];
	}
}

@end
