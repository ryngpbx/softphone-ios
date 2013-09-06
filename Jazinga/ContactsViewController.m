//
//  ContactsViewController.m
//
//  Created by John Mah on 12-05-10.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import "ContactsViewController.h"

@interface ContactsViewController ()

@end

@implementation ContactsViewController

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
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (void)viewDidAppear:(BOOL)animated {
    self.delegate = self;
    self.peoplePickerDelegate = self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark UINavigationControllerDelegate methods

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    switch ([navigationController.viewControllers count]) {
        case 1:
            viewController.navigationItem.rightBarButtonItem = nil;
            break;
        case 2: {
            UIBarButtonItem *addButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonClicked)];
            [viewController.navigationItem setRightBarButtonItem:addButtonItem animated:NO];
            break;
        }
        case 3: {
            UIBarButtonItem *editButtonItem;
            if ([viewController isKindOfClass:[ABPersonViewController class]]) {
                editButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editButtonClicked:)];
                // self.personView = (ABPersonViewController*) viewController;
                // self.personView.allowsEditing = YES;
                [viewController.navigationItem setRightBarButtonItem:editButtonItem animated:NO];
            } else {
                //ABPersonNewViewController
                //No need to add codes here
            }            
            break;
        }           
        default: {          
            UIBarButtonItem *cancelButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(addButtonClicked)];
            [viewController.navigationItem setRightBarButtonItem:cancelButtonItem animated:NO];
            break;
        }
    }   
}

#pragma mark IBActions

- (IBAction)showPicker:(id)sender {
    [self presentViewController:sender animated:YES completion:nil];
}

- (IBAction)addButtonClicked {
    
}

- (IBAction)editButtonClicked:(id)sender {
    
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
        return NO;
    }
    return YES;
}

@end
