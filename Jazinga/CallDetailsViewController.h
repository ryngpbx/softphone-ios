//
//  CallDetailsViewController.h
//  Jazinga Softphone
//
//  Created by John Mah on 12-07-09.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>
#import "EditingPersonViewController.h"
#import "DetailsHeaderCell.h"
#import "CallSectionHeaderCell.h"
#import "CallCell.h"
#import "ButtonCell.h"
#import "Call.h"

@interface CallDetailsViewController : UITableViewController <UITableViewDelegate, UITableViewDataSource,ABNewPersonViewControllerDelegate, ABPeoplePickerNavigationControllerDelegate,ABPersonViewControllerDelegate,EditingPersonViewControllerDelegate>

@property (strong, nonatomic) NSArray *calls;
@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;
@property (strong, nonatomic) NSDateFormatter *dayFormatter;
@property (strong, nonatomic) NSDateFormatter *dayMediumFormatter;

@property (strong, nonatomic) DetailsHeaderCell *prototypeDetailsHeaderCell;
@property (strong, nonatomic) CallSectionHeaderCell *prototypeCallSectionHeaderCell;
@property (strong, nonatomic) CallCell *prototypeCallCell;
@property (strong, nonatomic) UITableViewCell *prototypeStyledCell;
@property (strong, nonatomic) ButtonCell *prototypeButtonCell;

@property NSString *name;
@property NSString *number;
@property Contact *contact;
@property UIImage *image;
@property ABMultiValueRef values;

@property ABAddressBookRef addressBook;

@end
