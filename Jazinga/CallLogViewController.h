//
//  CallLogViewController.h
//
//  Created by John Mah on 12-05-10.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>

@interface CallLogViewController : UITableViewController <UITableViewDelegate, UITableViewDataSource>

@property (strong,nonatomic) IBOutlet UITableView* tableView;
@property (strong,nonatomic) NSManagedObjectContext* managedObjectContext;
@property (strong,nonatomic) NSMutableArray *calls;
@property (strong,nonatomic) NSDateFormatter *dateFormatter;
@property (nonatomic) BOOL isFiltered;
@property (strong,nonatomic) NSMutableArray *missedCalls;
@property (nonatomic) ABAddressBookRef addressBook;

- (IBAction)segmentAction:(id)sender;
- (IBAction)clearButtonClicked:(id)sender;

- (IBAction)update:(id)sender;

- (NSArray*)listAtIndex:(NSIndexPath*)indexPath;

@end

