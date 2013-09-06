//
//  DialViewController.m
//
//  Created by John Mah on 12-05-10.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import "DialViewController.h"
#import "AppDelegate.h"
#import "PhoneNumber.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface DialViewController ()

@end

@implementation DialViewController

@synthesize number;
@synthesize contactInfo;
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
@synthesize num0button;
@synthesize poundButton;
@synthesize addContactButton;
@synthesize callButton;
@synthesize backspaceButton;
@synthesize dialpadBkColor;
@synthesize dialpadSelectedBkColor;
@synthesize labelBkColor;
@synthesize buttonToNumberDict;
@synthesize numberToDTMFSoundDict;
@synthesize accepted;
@synthesize currentContactName;
@synthesize shouldPlayFeedbackSounds;
@synthesize zeroTimer;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
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
    
    self.numberToDTMFSoundDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithInt:1200], @"0",
                                  [NSNumber numberWithInt:1201], @"1",
                                  [NSNumber numberWithInt:1202], @"2",
                                  [NSNumber numberWithInt:1203], @"3",
                                  [NSNumber numberWithInt:1204], @"4",
                                  [NSNumber numberWithInt:1205], @"5",
                                  [NSNumber numberWithInt:1206], @"6",
                                  [NSNumber numberWithInt:1207], @"7",
                                  [NSNumber numberWithInt:1208], @"8",
                                  [NSNumber numberWithInt:1209], @"9",
                                  [NSNumber numberWithInt:1210], @"*",
                                  [NSNumber numberWithInt:1211], @"#",
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
    
    contactInfo.hidden = YES;
    
    [callButton useGreenConfirmStyle];
    [callButton setCornerRadius:0.0f];
    
    addressBook = ABAddressBookCreate();
    
    // configure dial settings
    [self reloadSettings:nil];
    
    // register for notifications
    NSNotificationCenter *dnc = [NSNotificationCenter defaultCenter];
    [dnc addObserver:self selector:@selector(reloadSettings:)
                name:NSUserDefaultsDidChangeNotification object:nil];
    [dnc addObserver:self selector:@selector(connect:)
                name:UIApplicationDidBecomeActiveNotification object:nil];
    [dnc addObserver:self selector:@selector(disconnect:)
                name:UIApplicationWillResignActiveNotification object:nil];
	
	
	// add listener for changes in network stack/SIP registration
	[dnc addObserver:self
			selector:@selector(updateRegistrationStatus:)
				name:kReachabilityChangedNotification
			  object:nil];
	[dnc addObserver:self
			selector:@selector(updateRegistrationStatus:)
				name:kSIPRegistrationChangedNotification
			  object:nil];

}

- (void)viewDidUnload
{
    // unregister for notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    CFRelease(addressBook);

    [self setNumber:nil];
    [self setNum1button:nil];
    [self setNum2button:nil];
    [self setNum3button:nil];
    [self setNum4button:nil];
    [self setNum5button:nil];
    [self setNum6button:nil];
    [self setNum7button:nil];
    [self setNum8button:nil];
    [self setNum9button:nil];
    [self setStarButton:nil];
    [self setNum0button:nil];
    [self setPoundButton:nil];
    [self setAddContactButton:nil];
    [self setCallButton:nil];
    [self setBackspaceButton:nil];
    [self setContactInfo:nil];
    
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self connect:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self disconnect:nil];
}


#pragma mark - Update info

- (void)updateRegistrationStatus:(id)sender
{
	BOOL registered = [[SIPAccountManager sharedAccountManager] hasValidRegistration];
	
	if (registered == YES) {
		[self.callButton useGreenConfirmStyle];
		[self.callButton setCornerRadius:0.0f];
		[self.callButton setEnabled:YES];
		[self.callButton.imageView setImage:[UIImage imageNamed:@"call"]];
	} else {
		[self.callButton useRedDeleteStyle];
		[self.callButton setCornerRadius:0.0f];
		[self.callButton setEnabled:NO];
		[self.callButton.imageView setImage:[UIImage imageNamed:@"block"]];
	}
	
	[self.callButton setNeedsDisplay];
}

#pragma mark - IBAction selectors

- (void)connect:(id)sender
{
#ifdef USE_DTMF_DIAL_SOUNDS
    // play sounds thru loudspeaker
    pjmedia_aud_dev_route route = PJMEDIA_AUD_DEV_ROUTE_LOUDSPEAKER;
    pjsua_snd_set_setting(PJMEDIA_AUD_DEV_CAP_OUTPUT_ROUTE, &route, PJ_TRUE);
#endif
}

- (void)disconnect:(id)sender
{
}

- (void)reloadSettings:(id)sender
{
    self.shouldPlayFeedbackSounds = [[NSUserDefaults standardUserDefaults] boolForKey:@"default_dial_feedback"];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (IBAction)buttonTouchDown:(id)sender {
    [sender setBackgroundColor:dialpadSelectedBkColor];

    // append button value to label
    NSString *textToAppend = nil;
    textToAppend = [buttonToNumberDict objectForKey:[NSValue valueWithNonretainedObject:sender]];
    if (textToAppend != nil) {
        // update the label text
        NSString *currentText = [number text];
        [self updateContactInfoUsingPhoneNumber:[currentText stringByAppendingString:textToAppend]];
        
        // if is '0' key, then start timer to fire after a period to change to '+'
        if (sender == num0button) {
            self.zeroTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 
                                                          target:self 
                                                        selector:@selector(updateZeroTimerFired:) 
                                                        userInfo:nil 
                                                         repeats:NO];
        }
    }

    // start playing DTMF
    [self startPlayingDTMF:textToAppend];
}

- (IBAction)buttonTouchUp:(id)sender {
    [zeroTimer invalidate];
    
    [sender performSelector:@selector(setBackgroundColor:) 
                 withObject:dialpadBkColor 
                 afterDelay:0.02];

    NSString *textToAppend = [buttonToNumberDict objectForKey:[NSValue valueWithNonretainedObject:sender]];
    [self stopPlayingDTMF:[textToAppend characterAtIndex:0]];
}

- (void)updateZeroTimerFired:(id)sender
{
    // delete last char from string
    NSString *currentText = [number text];
    NSUInteger len = [currentText length];
    if (currentText != nil && len > 0) {
        // update the number
        [self updateContactInfoUsingPhoneNumber:[[currentText substringToIndex:len-1] stringByAppendingString:@"+"]];
    }
    
    // invalidate the timer
    [self.zeroTimer invalidate];
}

- (IBAction)delButtonDown:(id)sender {
    [self buttonTouchDown:sender];
}

- (IBAction)delButtonUp:(id)sender {
    [sender setBackgroundColor:dialpadBkColor];
    
    // delete last char from string
    NSString *currentText = [number text];
    NSUInteger len = [currentText length];
    if (currentText != nil && len > 0) {
        // update the number
        [self updateContactInfoUsingPhoneNumber:[currentText substringToIndex:len-1]];
    }
}

- (void)updateContactInfoUsingPhoneNumber:(NSString*)updatedNumber {
    // update the dialer number
    number.text = [PhoneNumber format:updatedNumber];
    
    // match number to a contact
    [self match:updatedNumber];
}

- (void)match:(NSString*)contactNumber
{
    // try and match number to an address book contact
    NSDictionary *matchResults = [PhoneNumber match:contactNumber];
    if (matchResults == nil) {
        currentContactName = @"";
        contactInfo.hidden = YES;
        return;
    }

    // get match results from address book search
    ABRecordID pid = [[matchResults objectForKey:@"contactID"] integerValue];
    ABMultiValueIdentifier mvid = [[matchResults objectForKey:@"valueID"] integerValue];
    if (pid == kABRecordInvalidID || mvid == kABMultiValueInvalidIdentifier) {
        currentContactName = @"";
        contactInfo.hidden = YES;
        return;
    };
    
    // find name and phone label type
    ABRecordRef person = ABAddressBookGetPersonWithRecordID(addressBook, pid);
    if (person == NULL) return;

    ABMultiValueRef mv = ABRecordCopyValue(person, kABPersonPhoneProperty);
    NSInteger index = ABMultiValueGetIndexForIdentifier(mv, mvid);
    NSString *compositeName = (__bridge_transfer NSString *)ABRecordCopyCompositeName(person);
    CFStringRef currPhoneLabel = ABMultiValueCopyLabelAtIndex(mv, index);
    
    // update UI elements
    currentContactName = [NSString stringWithString:compositeName];
    contactInfo.text = [currentContactName stringByAppendingFormat:@"   %@", (__bridge_transfer NSString*)ABAddressBookCopyLocalizedLabel(currPhoneLabel), nil];
    contactInfo.hidden = NO;
    
    // release copies
    CFRelease(mv);
    CFRelease(currPhoneLabel);
}

- (IBAction)contactsButtonDown:(id)sender {
    [self buttonTouchDown:sender];
}

- (IBAction)contactsButtonUp:(id)sender {
    [sender setBackgroundColor:dialpadBkColor];

    // present options to add or edit
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                delegate:self 
                       cancelButtonTitle:@"Cancel" 
                  destructiveButtonTitle:nil 
                       otherButtonTitles:@"Create New Contact", @"Add to Existing Contact", nil];
    [sheet showFromTabBar:self.tabBarController.tabBar];
}

- (IBAction)call:(id)sender {
    // don't try and dial an empty number
    NSString *numberToDial = [number text];
    if ([numberToDial length] == 0) {
		numberToDial = [[NSUserDefaults standardUserDefaults] stringForKey:@"last_dialed_number"];
		if (numberToDial != nil && [numberToDial length] > 0)
			[self updateContactInfoUsingPhoneNumber:numberToDial];
		return;
	}
	
	// write last number dialed to preferences
	[[NSUserDefaults standardUserDefaults] setValue:numberToDial forKey:@"last_dialed_number"];
	
    // dial number then reset the dialer
    [[AppDelegate sharedAppDelegate] call:currentContactName
                               withNumber:numberToDial];
    [self reset];
}

- (void)reset {
    number.text = @"";
    contactInfo.text = @"";
    contactInfo.hidden = YES;
}

#pragma mark - DTMF generation

- (void)startPlayingDTMF:(NSString*)digit
{
    if (shouldPlayFeedbackSounds == NO) return;
    
#ifdef USE_DTMF_DIAL_SOUND
    pjmedia_tone_digit d;
    d.digit = digit;
    d.on_msec = 100;
    d.off_msec = 0;
    d.volume = 0;
    
    tonegen_data *tonegen = [[AppDelegate sharedAppDelegate] dialer_tonegen];
    pjmedia_tonegen_play_digits(tonegen->tonegen, 1, &d, PJMEDIA_TONEGEN_LOOP);
#else
    NSNumber *numSoundID = [numberToDTMFSoundDict objectForKey:digit];
    if (numSoundID == nil) return;
    
    AudioServicesPlaySystemSound([numSoundID integerValue]);
#endif
}

- (void)stopPlayingDTMF:(unichar)digit
{
    if (shouldPlayFeedbackSounds == NO) return;

#ifdef USE_DTMF_DIAL_SOUND
    pjmedia_tone_digit d;
    d.digit = digit;
    d.on_msec = 0;
    d.off_msec = 0;
    d.volume = 0;
    
    tonegen_data *tonegen = [[AppDelegate sharedAppDelegate] dialer_tonegen];
    pjmedia_tonegen_play_digits(tonegen->tonegen, 1, &d, 0);
#endif
}

- (void)speaker:(BOOL)on {
    UInt32 audioRouteOverride = on;
    AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryDefaultToSpeaker, 
                            sizeof(audioRouteOverride), &audioRouteOverride);
}

#pragma mark - Address Book delegate

- (void)newPersonViewController:(ABNewPersonViewController *)newPersonView 
	   didCompleteWithNewPerson:(ABRecordRef)person
{
	// check to see if they hit save
	if (person != NULL) {
        [self updateContactInfoUsingPhoneNumber:[number text]];
	}
	
    [newPersonView.presentingViewController dismissModalViewControllerAnimated:YES];
}

#pragma mark - Action Sheet delegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) {
        // new contact based on current phone number entered
        ABRecordRef newPerson = ABPersonCreate();
        
        // create multi-val phone number property
        ABMultiValueRef mv = ABMultiValueCreateMutable(kABMultiStringPropertyType);
        ABMultiValueAddValueAndLabel(mv, (__bridge CFTypeRef)[number text], kABPersonPhoneMobileLabel, NULL);
        CFErrorRef error = NULL;
        ABRecordSetValue(newPerson, kABPersonPhoneProperty, mv, &error);
        
        // open editor
        [self newContact:nil person:newPerson];

        // cleanup
        CFRelease(mv);
        CFRelease(newPerson);
    } else if (buttonIndex == 1) {
        // from a existing contact, first pick a contact
        ABPeoplePickerNavigationController *picker = [[ABPeoplePickerNavigationController alloc] init];
        picker.peoplePickerDelegate = self;
        picker.addressBook = addressBook;
        
        // chained completion uses uses selection to open new person editor
        [self presentViewController:picker animated:YES completion:nil];
    } else if (buttonIndex == 2) {
        // cancelled
    }
}

- (void)newContact:(UINavigationController*)nc person:(ABRecordRef)person
{
    // create new person editor
    ABNewPersonViewController *npvc = [[ABNewPersonViewController alloc] init];
    [npvc setNewPersonViewDelegate:self];
    [npvc setAddressBook:addressBook];
    [npvc setDisplayedPerson:person];
    
    // create multi-val phone number property
    ABMultiValueRef mv = ABMultiValueCreateMutable(kABMultiStringPropertyType);
    ABMultiValueAddValueAndLabel(mv, (__bridge CFTypeRef)[number text], kABPersonPhoneMobileLabel, NULL);
    CFErrorRef error = NULL;
    ABRecordSetValue(person, kABPersonPhoneProperty, mv, &error);
    CFRelease(mv);

    // present editor modally in its own nav controller
    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:npvc]
                            animated:YES
                         completion:nil];
}

- (void)addToContact:(UINavigationController*)nc person:(ABRecordRef)person
{
    // see if we have an existing phone property
    CFErrorRef error = NULL;
    ABMultiValueIdentifier mvid;
    ABMultiValueRef values = ABRecordCopyValue(person, kABPersonPhoneProperty);
    ABMutableMultiValueRef mv = ABMultiValueCreateMutableCopy(values);
    if (mv != nil) {
        // insert new value at beginning of multi-val
        ABMultiValueAddValueAndLabel(mv, (__bridge CFTypeRef)[number text], kABPersonPhoneMobileLabel, &mvid);
    } else {
        // add current entered phone number to the selected contact
        mv = ABMultiValueCreateMutable(kABMultiStringPropertyType);
        ABMultiValueAddValueAndLabel(mv, (__bridge CFTypeRef)[number text], 
                                     kABPersonPhoneMobileLabel, &mvid);
    }

    ABRecordSetValue(person, kABPersonPhoneProperty, mv, &error);
    
    // cleanup
    CFRelease(values);
    CFRelease(mv);

    if (error != nil) return; // BUGBUG: handle error
    
    // create new person editor
    EditingPersonViewController *pvc = [[EditingPersonViewController alloc] init];
    [pvc setPersonViewDelegate:self];
    [pvc setEditingPersonViewDelegate:self];
    [pvc setAddressBook:addressBook];
    [pvc setDisplayedPerson:person];
    [pvc setAllowsEditing:YES];
    [pvc setEditing:YES];
    [pvc setHighlightedItemForProperty:kABMultiStringPropertyType withIdentifier:mvid];

    // push existing contact editor
    [nc pushViewController:pvc animated:YES];
}

#pragma mark - ABPeoplePickerNavigationController delegate

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person
{
    [self addToContact:peoplePicker person:person];
	return NO;
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker 
      shouldContinueAfterSelectingPerson:(ABRecordRef)person 
                                property:(ABPropertyID)property 
                              identifier:(ABMultiValueIdentifier)identifier
{
    [self addToContact:peoplePicker person:person];
	return NO;
}

- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker
{
	[peoplePicker dismissModalViewControllerAnimated:YES];
}

#pragma mark - ABPersonViewController delegate

- (BOOL)personViewController:(ABPersonViewController*)personViewController shouldPerformDefaultActionForPerson:(ABRecordRef)person 
                    property:(ABPropertyID)property 
                  identifier:(ABMultiValueIdentifier)identifierForValue
{
    return YES;
}

#pragma mark EditingPersonViewDelegate methods

-(void)editingPersonViewController:(EditingPersonViewController *)vc 
                  cancelledEditing:(ABRecordRef)person
{
}

- (void)editingPersonViewController:(EditingPersonViewController *)vc 
                    finishedEditing:(ABRecordRef)person
{
    [self updateContactInfoUsingPhoneNumber:[number text]];
}

@end
