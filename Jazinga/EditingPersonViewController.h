//
//  EditingPersonViewControllerViewController.h
//  Jazinga
//
//  Created by John Mah on 12-07-23.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <AddressBookUI/AddressBookUI.h>

@protocol EditingPersonViewControllerDelegate;

@interface EditingPersonViewController : ABPersonViewController

@property (nonatomic, assign) id<EditingPersonViewControllerDelegate> editingPersonViewDelegate;

@end

@interface EditingContactCardController : EditingPersonViewController

@end

@protocol EditingPersonViewControllerDelegate <NSObject>
- (void)editingPersonViewController:(EditingPersonViewController*)vc finishedEditing:(ABRecordRef)person;
- (void)editingPersonViewController:(EditingPersonViewController*)vc cancelledEditing:(ABRecordRef)person;
@end

