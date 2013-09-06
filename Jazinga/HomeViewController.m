//
//  HomeViewController.m
//  Jazinga Softphone
//
//  Created by John Mah on 12-06-26.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import "HomeViewController.h"
#import "AppDelegate.h"
#import "LoginViewController.h"
#import "InboundViewController.h"
#import "SIPCallDetails.h"

@interface HomeViewController ()

@end

@implementation HomeViewController

@synthesize peoplePicker;
@synthesize initialLogin;
@synthesize addressBook;

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
    
    self.addressBook = ABAddressBookCreate();
    self.delegate = self;
    self.initialLogin = YES;

	// create 'Contacts' view controller
    peoplePicker = [[ABPeoplePickerNavigationController alloc] init];
    peoplePicker.delegate = self;
    peoplePicker.peoplePickerDelegate = self;
    peoplePicker.navigationController.delegate = self;
    UITabBarItem *peoplePickerTabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemContacts tag:0];
    peoplePicker.tabBarItem = peoplePickerTabBarItem;
    self.peoplePicker = peoplePicker;

    NSMutableArray *reordered = [NSMutableArray arrayWithArray:[self viewControllers]];
    [reordered insertObject:peoplePicker atIndex:2];
    [self setViewControllers:reordered];

    // listen for changes to missed call count
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateBadgeValue)
                                                 name:NSUserDefaultsDidChangeNotification
                                               object:nil];    
}

- (void)viewDidUnload
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    self.peoplePicker = nil;
    CFRelease(self.addressBook);

    [super viewDidUnload];
}

-(void)viewWillAppear:(BOOL)animated {
    // self.selectedIndex = 0;
}

-(void)viewDidAppear:(BOOL)animated {
    // check to see if logged in already
    if ([[SIPAccountManager sharedAccountManager] isLoggedIn] == NO)
        [self performSegueWithIdentifier:@"Login" sender:self];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark Segue methods

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSString *identifier = [segue identifier];
    
    if ([sender respondsToSelector:@selector(setCallID:)] == YES) {
        if ([identifier isEqualToString:@"IncomingCall"]) {
            InboundViewController *ivc = [segue destinationViewController];
            SIPCallDetails *scd = (SIPCallDetails*)sender;
            ivc.callDetails = scd;
        } else if ([identifier isEqualToString:@"OutgoingCall"]) {
            InboundViewController *ivc = [segue destinationViewController];
            SIPCallDetails *scd = (SIPCallDetails*)sender;
            ivc.callDetails = scd;
        }
    } else if ([identifier isEqualToString:@"Login"]) {
        LoginViewController *lvc = [segue destinationViewController];
        lvc.initialLogin = initialLogin;
        initialLogin = NO;
    }
}

#pragma mark - Notification handlers

- (void)updateBadgeValue
{
    // update last missed call count from pref key
    NSInteger lastMissedCallCount = [[NSUserDefaults standardUserDefaults] integerForKey:@"MissedCalls"];
    
    // default to none unless missed calls
    NSString *value = nil;
    if (lastMissedCallCount > 0) {
        value = [NSString stringWithFormat:@"%u", lastMissedCallCount, nil];
    }
    
    [[self.tabBar.items objectAtIndex:1] setBadgeValue:value];
}

#pragma mark UITabBarControllerDelegate methods

- (void) tabBarController:(UITabBarController*)aTabBarController
  didSelectViewController:(UIViewController*)viewController
{
    // reset missed call count
    [[NSUserDefaults standardUserDefaults] setInteger:0
                                               forKey:@"MissedCalls"]; 

    // clear badge value
    viewController.tabBarItem.badgeValue = nil;
}

#pragma mark ABPeoplePickerNavigationControllerDelegate methods

- (void)peoplePickerNavigationControllerDidCancel:
(ABPeoplePickerNavigationController *)peoplePicker
{
    // [self dismissModalViewControllerAnimated:YES];
}

- (BOOL)peoplePickerNavigationController:
(ABPeoplePickerNavigationController *)peoplePicker
      shouldContinueAfterSelectingPerson:(ABRecordRef)person {
    // create new person editor
    EditingContactCardController *pvc = [[EditingContactCardController alloc] init];
    [pvc setPersonViewDelegate:self];
    [pvc setEditingPersonViewDelegate:self];
    [pvc setAddressBook:addressBook];
    [pvc setDisplayedPerson:person];
    [pvc setAllowsEditing:YES];
    [pvc setShouldShowLinkedPeople:YES];
    
    // push existing contact editor
    [self.peoplePicker pushViewController:pvc animated:YES];
    
    return NO;
}

- (BOOL)peoplePickerNavigationController:
(ABPeoplePickerNavigationController *)peoplePicker
      shouldContinueAfterSelectingPerson:(ABRecordRef)person
                                property:(ABPropertyID)property
                              identifier:(ABMultiValueIdentifier)identifier
{
    // don't initiate normal phone calls if phone #, use SIP instead
    if (property == kABPersonPhoneProperty) {
        // get selected phone number
        ABMultiValueRef values = ABRecordCopyValue(person, kABPersonPhoneProperty);
        CFIndex index = ABMultiValueGetIndexForIdentifier(values, identifier);
        NSString *contactName = (__bridge_transfer NSString *)ABRecordCopyCompositeName(person);
        NSString *currPhoneNumber = (__bridge_transfer NSString*)ABMultiValueCopyValueAtIndex(values, index);

        // now dial the number
        [[AppDelegate sharedAppDelegate] call:contactName withNumber:currPhoneNumber];
        
        // release the values
        CFRelease(values);

        return NO;
    }
    return YES;
}

- (void)newPersonViewController:(ABNewPersonViewController *)newPersonView 
       didCompleteWithNewPerson:(ABRecordRef)person {
    [newPersonView dismissModalViewControllerAnimated:YES];
}

#pragma mark UINavigationControllerDelegate methods

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    switch ([navigationController.viewControllers count]) {
        case 1:
            viewController.navigationItem.rightBarButtonItem = nil;
            break;
        case 2: {
            viewController.navigationItem.rightBarButtonItem = nil;
            /*
            UIBarButtonItem *addButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonClicked:)];
            [viewController.navigationItem setRightBarButtonItem:addButtonItem animated:NO];
            */
            break;
        }
        case 3: {
            if ([viewController isKindOfClass:[ABPersonViewController class]]) {
                /*
                UIBarButtonItem *editButtonItem;
                editButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editButtonClicked:)];
                ABPersonViewController *pvc = (ABPersonViewController*) viewController;
                pvc.allowsEditing = YES;
                [viewController.navigationItem setRightBarButtonItem:editButtonItem animated:NO];
                */
            } else {
                //ABPersonNewViewController
                //No need to add codes here
            }            
            break;
        }           
        default: {
            /*
            UIBarButtonItem *cancelButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(addButtonClicked:)];
            [viewController.navigationItem setRightBarButtonItem:cancelButtonItem animated:NO];
            */
            break;
        }
    }   
}

#pragma mark Contacts buttons

- (IBAction)addButtonClicked:(id)sender {
    ABNewPersonViewController *view = [[ABNewPersonViewController alloc] init];
    view.newPersonViewDelegate = self;
    UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:view];
    [self presentViewController:nc animated:YES completion:nil];
}

- (IBAction)editButtonClicked:(id)sender {
    
}

#pragma mark EditingPersonViewControllerDelegate methods

- (BOOL)personViewController:(ABPersonViewController*)personViewController shouldPerformDefaultActionForPerson:(ABRecordRef)person 
                    property:(ABPropertyID)property 
                  identifier:(ABMultiValueIdentifier)identifier
{
    // don't initiate normal phone calls if phone #, use SIP instead
    if (property == kABPersonPhoneProperty) {
        // get selected phone number
        ABMultiValueRef values = ABRecordCopyValue(person, kABPersonPhoneProperty);
        CFIndex index = ABMultiValueGetIndexForIdentifier(values, identifier);
        NSString *contactName = (__bridge_transfer NSString *)ABRecordCopyCompositeName(person);
        NSString *currPhoneNumber = (__bridge_transfer NSString*)ABMultiValueCopyValueAtIndex(values, index);
        
        // now dial the number
        [[AppDelegate sharedAppDelegate] call:contactName withNumber:currPhoneNumber];
        
        // release the values
        CFRelease(values);
        
        return NO;
    }
    return YES;
}

-(void)editingPersonViewController:(EditingPersonViewController *)vc 
                  cancelledEditing:(ABRecordRef)person
{
}

- (void)editingPersonViewController:(EditingPersonViewController *)vc 
                    finishedEditing:(ABRecordRef)person
{
}

@end
