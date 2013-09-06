//
//  ContactsViewController.h
//
//  Created by John Mah on 12-05-10.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//


#import <UIKit/UIKit.h>
#import <AddressBookUI/AddressBookUI.h>

/*
@interface ContactsViewController : UIViewController <ABPeoplePickerNavigationControllerDelegate, UINavigationControllerDelegate> {
}
*/
@interface ContactsViewController : ABPeoplePickerNavigationController <ABPeoplePickerNavigationControllerDelegate, UINavigationControllerDelegate> {
}

- (IBAction)showPicker:(id)sender;

@end
