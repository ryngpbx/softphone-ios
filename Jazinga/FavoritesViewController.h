//
//  FavoritesViewController.h
//  Jazinga
//
//  Created by John Mah on 12-07-24.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>
#import "Favorite.h"

@interface FavoritesViewController : UITableViewController <UITableViewDelegate, UITableViewDataSource, ABPeoplePickerNavigationControllerDelegate, ABPersonViewControllerDelegate, ABUnknownPersonViewControllerDelegate>

@property (strong,nonatomic) IBOutlet UITableView *tableView;
@property (strong,nonatomic) NSManagedObjectContext *managedObjectContext;
@property (strong,nonatomic) NSMutableArray *favorites;
@property (strong,nonatomic) NSArray *directory;
@property (strong,nonatomic) NSArray *teams;
@property (strong,nonatomic) NSArray *apps;
@property ABAddressBookRef addressBook;
@property double highestOrderSeen;
@property BOOL showDirectory;

@end
