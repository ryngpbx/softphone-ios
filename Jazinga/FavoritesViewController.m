//
//  FavoritesViewController.m
//  Jazinga
//
//  Created by John Mah on 12-07-24.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import "FavoritesViewController.h"
#import "AppDelegate.h"
#import "PhoneNumber.h"
#import "Extension.h"

@interface FavoritesViewController ()

@end

@implementation FavoritesViewController

@synthesize tableView;
@synthesize managedObjectContext;
@synthesize favorites;
@synthesize directory;
@synthesize teams;
@synthesize apps;
@synthesize addressBook;
@synthesize highestOrderSeen;
@synthesize showDirectory;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.addressBook = ABAddressBookCreate();
    self.highestOrderSeen = 0.0f;
	self.showDirectory = YES;

    // create middle toolbar for selecting all/missed buttons
    UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithItems:
                                            [NSArray arrayWithObjects:
                                             @"Extensions", @"Favorites", nil]];
    [segmentedControl addTarget:self action:@selector(segmentAction:) forControlEvents:UIControlEventValueChanged];
    segmentedControl.frame = CGRectMake(0,0,150,30);
    segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
    segmentedControl.momentary = NO;
    segmentedControl.selectedSegmentIndex = 0; // TODO: remember last
    self.navigationItem.titleView = segmentedControl;

	[self updateNavigationBar];

    // use app delegate's object context
    self.managedObjectContext = [AppDelegate sharedAppDelegate].managedObjectContext;
    
    // register for save notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(update:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:managedObjectContext];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(updatedExtensions:)
												 name:kExtensionsChangedNotification
												object:nil];

    // load initial call list
    [self update:managedObjectContext];
}

- (void)viewDidUnload
{
    [self setTableView:nil];
    CFRelease(self.addressBook);

    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Utility selectors

- (void)updateNavigationBar
{
	if (self.showDirectory == YES) {
		// remove nav items if showing extensions
		self.navigationItem.leftBarButtonItem = nil;
		self.navigationItem.rightBarButtonItem = nil;
	} else {
		// create nav items if showing favorites
		self.navigationItem.leftBarButtonItem = self.editButtonItem;
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(add:)];
	}
}

-(void)segmentAction:(id)sender {
    UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
    self.showDirectory = (segmentedControl.selectedSegmentIndex == 0 ? YES : NO);

	// end editing if in middle of editing
	[self setEditing:NO animated:YES];
	
	// add the edit/add buttons to nav bar
	[self updateNavigationBar];
	
	// redraw the list
    [tableView reloadData];
}

- (void)add:(id)sender
{
    ABPeoplePickerNavigationController *ppvc = [[ABPeoplePickerNavigationController alloc] init];
    ppvc.peoplePickerDelegate = self;
    //ppvc.navigationItem.prompt = @"Choose a contact to add to Favorites";
    [self presentViewController:ppvc animated:YES completion:nil];
}

- (IBAction)update:(id)sender
{
    // load initial call list
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription
                                   entityForName:@"Favorite" 
                                   inManagedObjectContext:managedObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"order" ascending:YES]]];
    
    // retrieve favorites
    NSError *error;
    NSArray *tmpCalls = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error != NULL) return;
    
    // enumerate the array
    self.favorites = [NSMutableArray array];
    NSEnumerator *e = [tmpCalls objectEnumerator];
    Favorite *next;
    while (next = [e nextObject]) {
        // add to main list
        [self.favorites addObject:next];
        
        // keep track of highest order
        self.highestOrderSeen = MAX(self.highestOrderSeen, [next.order doubleValue]);
    }
    
    // force redraw of call log view
    [tableView reloadData];
}

- (IBAction)updatedExtensions:(id)sender
{
	// reload extensions
	self.directory = [[AppDelegate sharedAppDelegate] extensions];
	self.teams = [[AppDelegate sharedAppDelegate] teams];
	self.apps = [[AppDelegate sharedAppDelegate] apps];
	
	// force redraw of table
	[tableView reloadData];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    if (!editing)
        [self.managedObjectContext save:nil];
}

#pragma mark - List item population

- (id)itemAtIndex:(NSIndexPath *)indexPath
{
	if (showDirectory == YES) {
		switch (indexPath.section) {
			default:
			case 0:
				return [directory objectAtIndex:indexPath.row];
			case 1:
				return [teams objectAtIndex:indexPath.row];
			case 2:
				return [apps objectAtIndex:indexPath.row];
		}
	} else {
		return [favorites objectAtIndex:indexPath.row];
	}
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return (self.showDirectory ? 3 : 1);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (showDirectory) {
		switch (section) {
			default:
			case 0:
				return [directory count];
			case 1:
				return [teams count];
			case 2:
				return [apps count];
		}
	} else {
		return [favorites count];
	}
}

- (UITableViewCell *)tableView:(UITableView *)tv 
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	// fill in cell details
	if (showDirectory == YES) {
		return [self configureExtensionForIndexPath:indexPath];
	} else {
		return [self configureFavoriteForIndexPath:indexPath];
	}
}

- (UITableViewCell*)configureExtensionForIndexPath:(NSIndexPath*)indexPath
{
	// create cell for table
    static NSString *CellIdentifier = @"Cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:CellIdentifier];
    }

	// real extension numbers
	if (indexPath.section == 0) {
		Extension *extension = [directory objectAtIndex:indexPath.row];
		cell.textLabel.text = extension.name;
		cell.detailTextLabel.text = extension.phoneNumber;
		cell.accessoryType = UITableViewCellAccessoryNone;
	} else if (indexPath.section == 1) {
		Extension *extension = [teams objectAtIndex:indexPath.row];
		cell.textLabel.text = extension.name;
		cell.detailTextLabel.text = extension.phoneNumber;
		cell.accessoryType = UITableViewCellAccessoryNone;
	} else if (indexPath.section == 2) {
		Extension *extension = [apps objectAtIndex:indexPath.row];
		cell.textLabel.text = extension.name;
		cell.detailTextLabel.text = extension.phoneNumber;
		cell.accessoryType = UITableViewCellAccessoryNone;
	}

	return cell;
}

- (UITableViewCell*)configureFavoriteForIndexPath:(NSIndexPath*)indexPath
{
	// create cell for table
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:CellIdentifier];
    }
    
	Favorite *favorite = [self itemAtIndex:indexPath];
	ABRecordID pid = [favorite.contactID integerValue];
	ABMultiValueIdentifier mvid = [favorite.valueID integerValue];
	
	// use the phone number by default
	cell.textLabel.text = [PhoneNumber format:[favorite phoneNumber]];
	cell.detailTextLabel.text = @"Unknown";
	cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
	
	if (pid != kABRecordInvalidID && mvid != kABMultiValueInvalidIdentifier) {
		// find name and phone label type
		ABRecordRef person = ABAddressBookGetPersonWithRecordID(addressBook, pid);
		if (person == NULL) return cell;
		
		ABMultiValueRef mv = ABRecordCopyValue(person, kABPersonPhoneProperty);
		NSInteger index = ABMultiValueGetIndexForIdentifier(mv, mvid);
		
		NSString *compositeName = nil;
		NSString *label = nil;
		if (index != -1) {
			compositeName = (__bridge_transfer NSString *)ABRecordCopyCompositeName(person);
			CFStringRef unlocalizedLabel = ABMultiValueCopyLabelAtIndex(mv, index);
			label = (__bridge_transfer NSString*)ABAddressBookCopyLocalizedLabel(unlocalizedLabel);
			
			// cleanup
			CFRelease(unlocalizedLabel);
		} else {
			compositeName = favorite.phoneNumber;
			label = nil;
		}
		
		// update UI elements
		cell.textLabel.text = [NSString stringWithString:compositeName];
		cell.detailTextLabel.text = label;
		cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
		
		// cleanup copies
		CFRelease(mv);
	}
	
	return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (showDirectory == YES) {
		switch (section) {
			case 0:
				return @"People";
			case 1:
				return @"Teams";
			case 2:
				return @"Apps";
		}
	}
	return @"Favorites";
}

- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)section {
	return nil;
}

-(float)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	switch (section) {
		default:
		case 0:
			return [directory count] > 0 ? -1 : 0;
		case 1:
			return [teams count] > 0 ? -1 : 0;
		case 2:
			return [apps count] > 0 ? -1 : 0;
			
	}
	return -1;
}

- (void)tableView:(UITableView*)tv 
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle 
forRowAtIndexPath:(NSIndexPath*)indexPath
{
	// if showing extensions then bail
	if (showDirectory == YES) return;

    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // get item reference in current call source
        Favorite *favToDelete = [self itemAtIndex:indexPath];
        
        // one of these should fail (already done)
        [favorites removeObject:favToDelete];
        
        // remove from manage object context
        [managedObjectContext deleteObject:favToDelete];
        
        // remove call from the table view
        [tv deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                  withRowAnimation:(UITableViewRowAnimation)UITableViewRowAnimationBottom];
    }
}

- (void)tableView:(UITableView *)tableView 
accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
	// extensions don't support details
	if (showDirectory == YES) return;

    // get call from selection
    Favorite *favorite = [self itemAtIndex:indexPath];
    ABRecordRef person = ABAddressBookGetPersonWithRecordID(addressBook, [favorite.contactID integerValue]);
    if (person == NULL) {
        // create multi-val phone number property
        ABRecordRef newPerson = ABPersonCreate();
        ABMultiValueRef mv = ABMultiValueCreateMutable(kABMultiStringPropertyType);
        ABMultiValueAddValueAndLabel(mv, (__bridge CFTypeRef)favorite.phoneNumber, kABPersonPhoneMobileLabel, NULL);
        CFErrorRef error = NULL;
        ABRecordSetValue(newPerson, kABPersonPhoneProperty, mv, &error);

        ABUnknownPersonViewController *upvc = [[ABUnknownPersonViewController alloc] init];
        upvc.unknownPersonViewDelegate = self;
        upvc.displayedPerson = newPerson;
        upvc.allowsAddingToAddressBook = YES;
        [self.navigationController pushViewController:upvc animated:YES];
    } else {
        // setup person view
        ABPersonViewController *pvc = [[ABPersonViewController alloc] init];
        pvc.displayedPerson = person;
        pvc.allowsEditing = YES;
        pvc.personViewDelegate = self;
        [self.navigationController pushViewController:pvc animated:YES];
    }
}

// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView 
moveRowAtIndexPath:(NSIndexPath *)fromIndexPath 
      toIndexPath:(NSIndexPath *)toIndexPath
{
	// can't re-order extensions
	if (showDirectory == YES) return;
	
    // instead of swapping array objects, we just exchange the order attributes
    Favorite *from = [favorites objectAtIndex:fromIndexPath.row];
    Favorite *to = [favorites objectAtIndex:toIndexPath.row];
    NSNumber *tmpOrder = from.order;
    from.order = to.order;
    to.order = tmpOrder;
    
    // exchanges items in the tmp array
    [favorites exchangeObjectAtIndex:fromIndexPath.row 
                   withObjectAtIndex:toIndexPath.row];
}

// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView 
canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // deselect the row
    [tv deselectRowAtIndexPath:indexPath animated:YES];

	NSString *contactName = nil;
	NSString *currPhoneNumber = nil;

	if (showDirectory == YES) {
		Extension *extension = [self itemAtIndex:indexPath];
		contactName = extension.name;
		currPhoneNumber = extension.phoneNumber;
	} else {
		Favorite *favorite = [self itemAtIndex:indexPath];
		contactName = [PhoneNumber format:favorite.phoneNumber];
		currPhoneNumber = favorite.phoneNumber;

		ABRecordRef person = ABAddressBookGetPersonWithRecordID(addressBook, [favorite.contactID integerValue]);
		if (person != NULL) {
			ABMultiValueIdentifier identifier = [favorite.valueID integerValue];

			// get selected phone number
			ABMultiValueRef values = ABRecordCopyValue(person, kABPersonPhoneProperty);
			CFIndex index = ABMultiValueGetIndexForIdentifier(values, identifier);

			if (index != -1) {
				contactName = (__bridge_transfer NSString *)ABRecordCopyCompositeName(person);
				currPhoneNumber = (__bridge_transfer NSString*)ABMultiValueCopyValueAtIndex(values, index);
			}
			
			// cleanup copies
			CFRelease(values);
		}
	}

    // now dial the number
    [[AppDelegate sharedAppDelegate] call:contactName withNumber:currPhoneNumber];
}

#pragma mark - ABPeoplePickerNavigationControllerDelegate methods

- (void)peoplePickerNavigationControllerDidCancel:
(ABPeoplePickerNavigationController *)peoplePicker
{
    [peoplePicker dismissViewControllerAnimated:YES completion:nil];
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
        // now add the favourite
        [self addFavoritePerson:ABRecordGetRecordID(person) property:identifier];
        
        // dismiss picker
        [peoplePicker dismissViewControllerAnimated:YES completion:nil];
        
        return NO;
    }
    return YES;
}

#pragma mark - ABPersonViewControllerDelegate

- (BOOL)personViewController:(ABPersonViewController*)personViewController
shouldPerformDefaultActionForPerson:(ABRecordRef)person 
                    property:(ABPropertyID)property 
                  identifier:(ABMultiValueIdentifier)identifierForValue
{
    // don't initiate normal phone calls if phone #, use SIP instead
    if (property == kABPersonPhoneProperty) {
        // dismiss contact viewer/editor
        [self.navigationController popViewControllerAnimated:YES];

        // reset our back button to correct text
        return NO;
    
    }
    return YES;
}

#pragma mark - ABUnknownPersonViewControllerDelegate

- (void)unknownPersonViewController:(ABUnknownPersonViewController*)unknownPersonView
                 didResolveToPerson:(ABRecordRef)person
{
}

- (BOOL)unknownPersonViewController:(ABUnknownPersonViewController*)personViewController
shouldPerformDefaultActionForPerson:(ABRecordRef)person
                           property:(ABPropertyID)property
                         identifier:(ABMultiValueIdentifier)identifier
{
    return NO;
}

#pragma mark - Core Data

- (void)addFavoritePerson:(ABRecordID)recordID 
                 property:(ABPropertyID)propertyID
{
    NSManagedObjectContext *context = [self managedObjectContext];
    Favorite *favorite = [NSEntityDescription insertNewObjectForEntityForName:@"Favorite"
                                               inManagedObjectContext:context];
    favorite.contactID = [NSNumber numberWithInteger:recordID];
    favorite.valueID = [NSNumber numberWithInteger:propertyID];
    
    // lookup current phone number
    favorite.phoneNumber = [PhoneNumber numberFrom:recordID property:propertyID];
    double nextOrder = self.highestOrderSeen + 1.0f;
    favorite.order = [NSNumber numberWithDouble:nextOrder];
    self.highestOrderSeen = nextOrder;

    [context save:NULL];
}

@end
