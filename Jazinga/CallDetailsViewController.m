//
//  CallDetailsViewController.m
//  Jazinga Softphone
//
//  Created by John Mah on 12-07-09.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import "CallDetailsViewController.h"
#import "NSDate+RelativeTime.h"
#import <AddressBook/AddressBook.h>
#import "ButtonCell.h"
#import "AppDelegate.h"

@interface CallDetailsViewController ()

@end

@implementation CallDetailsViewController

@synthesize tableView;
@synthesize dateFormatter;
@synthesize dayFormatter;
@synthesize dayMediumFormatter;
@synthesize prototypeDetailsHeaderCell;
@synthesize prototypeCallSectionHeaderCell;
@synthesize prototypeCallCell;
@synthesize prototypeStyledCell;
@synthesize prototypeButtonCell;

@synthesize name;
@synthesize number;
@synthesize contact;
@synthesize image;

static NSString *DetailsHeaderIdentifier = @"DetailsHeaderCell";
static NSString *CallSectionHeaderIdentifer = @"CallSectionHeaderCell";
static NSString *CallIdentifier = @"CallCell";
static NSString *StyledIdentifier = @"StyledCell";
static NSString *ButtonIdentifier = @"ButtonCell";
static NSString *NumberIdentifier = @"NumberCell";

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

    // setup date formatter
    self.dateFormatter = [[NSDateFormatter alloc] init];
    [self.dateFormatter setDateFormat:@"h:mm a"];

    self.dayFormatter = [[NSDateFormatter alloc] init];
    [self.dayFormatter setDateStyle:NSDateFormatterShortStyle];
    [self.dayFormatter setTimeStyle:NSDateFormatterNoStyle];
    
    self.dayMediumFormatter = [[NSDateFormatter alloc] init];
    [self.dayMediumFormatter setDateStyle:NSDateFormatterMediumStyle];
    [self.dayMediumFormatter setTimeStyle:NSDateFormatterNoStyle];
    
    // hook up our table data
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    // register external .xib files for re-use
    [self.tableView registerNib:[UINib nibWithNibName:@"DetailsHeaderCell"
                                               bundle:[NSBundle mainBundle]]
         forCellReuseIdentifier:DetailsHeaderIdentifier];
    [self.tableView registerNib:[UINib nibWithNibName:@"CallSectionHeaderCell"
                                               bundle:[NSBundle mainBundle]]
         forCellReuseIdentifier:CallSectionHeaderIdentifer];
    [self.tableView registerNib:[UINib nibWithNibName:@"CallCell"
                                               bundle:[NSBundle mainBundle]]
         forCellReuseIdentifier:CallIdentifier];

    // convenience fields used later
    Call *call = [self.calls objectAtIndex:0];
    self.name = (call.name.length > 0 ? call.name : call.phoneNumber);
    self.number = call.phoneNumber;
    self.contact = call.contact;
    self.image = nil;

    if (self.contact != nil) {
        ABRecordID cid = [self.contact.contactID integerValue];
        ABRecordRef person = ABAddressBookGetPersonWithRecordID(self.addressBook, cid);
        
        // cache the image associated with contact
        if (person != NULL) {
            // get image if present
            if (ABPersonHasImageData(person) == YES) {
                NSData *data = (__bridge_transfer NSData*) ABPersonCopyImageData(person);
                self.image = [UIImage imageWithData:data];
            }
        
            // get list of phone number associated with this contact
            self.values = ABRecordCopyValue(person, kABPersonPhoneProperty);
        }
    }
}

- (void)viewDidUnload
{
    [self setTableView:nil];
    [self setPrototypeDetailsHeaderCell:nil];
    [self setPrototypeCallSectionHeaderCell:nil];
    [self setPrototypeCallCell:nil];
    [self setPrototypeButtonCell:nil];
    self.name = nil;
    self.number = nil;
    self.contact = nil;
    self.image = nil;

    CFRelease(self.addressBook);

    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - UITableViewControllerDelegate, etc.

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return UITableViewCellEditingStyleNone;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv
{
    return (self.contact != nil ? 2 : 3);
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)section
{
	return nil;
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)section
{
	return nil;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        // sections in header and call log parts
        return 2 + [self.calls count];
    } else if (section == 1) {
        // could be 1 number (unknown) or 1..n phone numbers (if a contact)
        return (self.values != NULL ? ABMultiValueGetCount(self.values) : 1);
    } else if (section == 2) {
        return 2;
    }
    return 1;
}

#define kUIRowHeight 45.0

- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    const NSInteger kFirstCallRow = 2;
    const NSInteger kLastCallRow = kFirstCallRow + [self.calls count];
    
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            // creates header cell
            if (self.prototypeDetailsHeaderCell == nil)
                prototypeDetailsHeaderCell = [tv dequeueReusableCellWithIdentifier:DetailsHeaderIdentifier];
            return self.prototypeDetailsHeaderCell.frame.size.height;
        } else if (indexPath.row == 1) {
            if (self.prototypeCallSectionHeaderCell == nil)
                prototypeCallSectionHeaderCell = [tv dequeueReusableCellWithIdentifier:CallSectionHeaderIdentifer];
            return self.prototypeCallSectionHeaderCell.frame.size.height;
        } else if (indexPath.row >= kFirstCallRow && indexPath.row < kLastCallRow) {
            if (self.prototypeCallCell == nil)
                prototypeCallCell = [tv dequeueReusableCellWithIdentifier:CallIdentifier];
            return self.prototypeCallCell.frame.size.height;
        }
    } else if (indexPath.section == 1 || indexPath.section == 2) {
        // create a prototype button cell so we can steal display values
        if (self.prototypeStyledCell == nil) {
            prototypeStyledCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:StyledIdentifier];
        }
        
        if (self.prototypeButtonCell == nil) {
            self.prototypeButtonCell = [[ButtonCell alloc] initWithFrame:CGRectZero
                                                         reuseIdentifier:ButtonIdentifier];
        }
        
        return self.prototypeButtonCell.frame.size.height;
    }
    return kUIRowHeight;
}

- (UITableViewCell *) tableView:(UITableView *)tv
		  cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    const NSInteger kFirstCallRow = 2;
    const NSInteger kLastCallRow = kFirstCallRow + [self.calls count];
    
    // set up the cell...
    UITableViewCell *cell = nil;
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            // creates header cell
            DetailsHeaderCell *dhc = [tv dequeueReusableCellWithIdentifier:DetailsHeaderIdentifier];
            dhc.name.text = (self.name.length > 0 ? self.name : self.number);
            if (self.image != nil) {
                [dhc cacheImage:image];
            }
            
            cell = dhc;
        } else if (indexPath.row == 1) {
            // create call section header cell
            CallSectionHeaderCell *cshc = [tv dequeueReusableCellWithIdentifier:CallSectionHeaderIdentifer];
            Call *call = [self.calls lastObject];
            
            // set incoming/outgoing type
            NSString *type = @"Incoming Calls";
            switch ([call.type integerValue]) {
                case CallTypeOutbound:
                    type = @"Outgoing Calls";
                    break;
                    
                default:
                    break;
            }
            cshc.type.text = type;
            cshc.date.text = [dayMediumFormatter stringFromDate:call.end];
            cell = cshc;
        } else if (indexPath.row >= kFirstCallRow && indexPath.row < kLastCallRow) {
            CallCell *cc = [tv dequeueReusableCellWithIdentifier:CallIdentifier];
            Call *rootCall = [self.calls objectAtIndex:0];
            
            // calculate call index
            NSInteger index = indexPath.row - 2;
            Call *call = [self.calls objectAtIndex:index];
            
            // set call start time
            cc.time.text = [dateFormatter stringFromDate:call.start];
            cc.duration.text = ([call.type integerValue] == CallTypeMissed ?
                                @"missed" : [call.start durationEndingAt:call.end]);
            
            // set date if not the same as latest call
            cc.date.text = @"";
            if ([call.start isSameDay:rootCall.start] == NO) {
                cc.date.text = [NSDateFormatter localizedStringFromDate:call.start
                                                              dateStyle:NSDateFormatterShortStyle
                                                              timeStyle:NSDateFormatterNoStyle];
            }
            
            cell = cc;
        }
        
        cell.backgroundView = [[UIView alloc] initWithFrame: CGRectZero];
        [cell.backgroundView setNeedsDisplay];

    } else if (indexPath.section == 1) {
        if (self.values == NULL) {
            if (indexPath.row == 0) {
                cell = [self createButtonCellIn:tv label:@"Call"];
            }
        } else if (self.values != NULL) {
            cell = [tv dequeueReusableCellWithIdentifier:NumberIdentifier];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2
                                              reuseIdentifier:NumberIdentifier];
            }

            NSUInteger index = indexPath.row;
            CFStringRef unlocalizedLabel = ABMultiValueCopyLabelAtIndex(self.values, index);
            cell.textLabel.text = (NSString*)CFBridgingRelease(ABAddressBookCopyLocalizedLabel(unlocalizedLabel));
            cell.detailTextLabel.text = (NSString*)CFBridgingRelease(ABMultiValueCopyValueAtIndex(self.values, index));
            
            // cleanup
            CFRelease(unlocalizedLabel);
        }
        if (indexPath.row == 0 && self.values == NULL) {
            cell = [self createButtonCellIn:tv label:@"Call"];
        }
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            cell = [self createButtonCellIn:tv label:@"Create New Contact"];
        } else if (indexPath.row == 1) {
            cell = [self createButtonCellIn:tv label:@"Add to Existing Contact"];
        }
    }
 
    // create a default cell
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:nil];
    }

	return cell;
}

- (ButtonCell*)createButtonCellIn:(UITableView*)tv label:(NSString*)label
{
    ButtonCell *bc = [tv dequeueReusableCellWithIdentifier:ButtonIdentifier];
    if (bc == nil) {
        bc = [[ButtonCell alloc] initWithFrame:CGRectZero
                               reuseIdentifier:ButtonIdentifier];
        bc.nameLabel.text = label;
        bc.nameLabel.textColor = prototypeStyledCell.detailTextLabel.textColor;
        bc.nameLabel.highlightedTextColor = [UIColor whiteColor];
        bc.nameLabel.font = [UIFont boldSystemFontOfSize:13];        
        [bc layoutSubviews];
    }
    
    return bc;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // deselect the row
    [tv deselectRowAtIndexPath:indexPath animated:YES];
    
    // if section is contacts section
    if (indexPath.section == 0) {
        return;
    } else if (indexPath.section == 1) {
        if (self.values == NULL) {
            // call number listed in header
            [[AppDelegate sharedAppDelegate] call:self.name
                                       withNumber:self.number];
        } else {
            // get phone number from contact info
            NSUInteger index = indexPath.row;
            [[AppDelegate sharedAppDelegate] call:self.name
                                       withNumber:(NSString*)CFBridgingRelease(ABMultiValueCopyValueAtIndex(self.values, index))];
        }
    } else if (indexPath.section == 2) {
        switch (indexPath.row) {
            case 0:
            {
                // new contact based on current phone number entered
                ABRecordRef newPerson = ABPersonCreate();
                
                // create multi-val phone number property
                ABMultiValueRef mv = ABMultiValueCreateMutable(kABMultiStringPropertyType);
                ABMultiValueAddValueAndLabel(mv, (__bridge CFTypeRef)self.number, kABPersonPhoneMobileLabel, NULL);
                CFErrorRef error = NULL;
                ABRecordSetValue(newPerson, kABPersonPhoneProperty, mv, &error);
                
                // open editor
                [self newContact:nil person:newPerson];
                
                // cleanup
                CFRelease(mv);
                CFRelease(newPerson);
                            
                break;
            }
                
            case 1:
            {
                // from a existing contact, first pick a contact
                ABPeoplePickerNavigationController *picker = [[ABPeoplePickerNavigationController alloc] init];
                picker.peoplePickerDelegate = self;
                picker.addressBook = self.addressBook;
                
                // chained completion uses uses selection to open new person editor
                [self presentViewController:picker animated:YES completion:nil];
                break;
            }
                
            default:
                break;
        }
    }
}

- (NSIndexPath*)tableView:(UITableView *)tv willSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
    if (indexPath.section >= 1)
        return indexPath;
    return nil;
}

- (void)newContact:(UINavigationController*)nc person:(ABRecordRef)person
{
    // create new person editor
    ABNewPersonViewController *npvc = [[ABNewPersonViewController alloc] init];
    [npvc setNewPersonViewDelegate:self];
    [npvc setAddressBook:self.addressBook];
    [npvc setDisplayedPerson:person];
    
    // create multi-val phone number property
    ABMultiValueRef mv = ABMultiValueCreateMutable(kABMultiStringPropertyType);
    ABMultiValueAddValueAndLabel(mv, (__bridge CFTypeRef)number, kABPersonPhoneMobileLabel, NULL);
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
        ABMultiValueAddValueAndLabel(mv, (__bridge CFTypeRef)number, kABPersonPhoneMobileLabel, &mvid);
    } else {
        // add current entered phone number to the selected contact
        mv = ABMultiValueCreateMutable(kABMultiStringPropertyType);
        ABMultiValueAddValueAndLabel(mv, (__bridge CFTypeRef)number,
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
    [pvc setAddressBook:self.addressBook];
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

#pragma mark - ABNewPersonViewController delegate

- (void)newPersonViewController:(ABNewPersonViewController *)newPersonView
	   didCompleteWithNewPerson:(ABRecordRef)person
{
	// check to see if they hit save
	if (person != NULL) {
        // [self updateContactInfoUsingPhoneNumber:[number text]];
	}
	
    [newPersonView.presentingViewController dismissModalViewControllerAnimated:YES];
}

#pragma mark EditingPersonViewDelegate methods

-(void)editingPersonViewController:(EditingPersonViewController *)vc
                  cancelledEditing:(ABRecordRef)person
{
}

- (void)editingPersonViewController:(EditingPersonViewController *)vc
                    finishedEditing:(ABRecordRef)person
{
    //[self updateContactInfoUsingPhoneNumber:[number text]];
}

@end
