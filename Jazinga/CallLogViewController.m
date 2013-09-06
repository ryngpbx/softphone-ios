//
//  CallLogViewController.m
//
//  Created by John Mah on 12-05-10.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import "CallLogViewController.h"
#import "CallLogCell.h"
#import "CallDetailsViewController.h"
#import "Call.h"
#import "AppDelegate.h"
#import "Contact.h"
#import <AddressBook/AddressBook.h>
#import "PhoneNumber.h"

static NSString *CellIdentifier = @"Call";
static NSString *MissedCellIdentifier = @"Missed";

@interface CallLogViewController ()

@end

@implementation CallLogViewController

@synthesize tableView;
@synthesize managedObjectContext;
@synthesize calls;
@synthesize dateFormatter;
@synthesize isFiltered;
@synthesize missedCalls;
@synthesize addressBook;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

	UINib *nib = [UINib nibWithNibName:@"CallLogCell" bundle:nil];
	[self.tableView registerNib:nib forCellReuseIdentifier:CellIdentifier];
	[self.tableView registerNib:nib forCellReuseIdentifier:MissedCellIdentifier];

    // address book ref
    addressBook = ABAddressBookCreate();

    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"h:mm a"];

    // hook up our table data
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    // create middle toolbar for selecting all/missed buttons
    UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithItems:
                                            [NSArray arrayWithObjects:
                                             @"All", @"Missed", nil]];
    [segmentedControl addTarget:self action:@selector(segmentAction:) forControlEvents:UIControlEventValueChanged];
    segmentedControl.frame = CGRectMake(0,0,150,30);
    segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
    segmentedControl.momentary = NO;
    segmentedControl.selectedSegmentIndex = 0; // TODO: remember last
    self.navigationItem.titleView = segmentedControl;
    
    // add edit button for recent call list
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    // use app delegate's object context
    self.managedObjectContext = [AppDelegate sharedAppDelegate].managedObjectContext;

    // register for save notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(update:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:managedObjectContext];

    // load initial call list
    [self update:managedObjectContext];
}

- (void)viewDidUnload
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (IBAction)update:(id)sender
{
    // load initial call list
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription
                                   entityForName:@"Call" 
                                   inManagedObjectContext:managedObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObjects:[NSSortDescriptor sortDescriptorWithKey:@"start" ascending:NO], nil]];

    // retrieve calls (but in wrong order)
    NSError *error;
    NSArray *tmpCalls = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error != NULL) return;
    
    // enumerate the array in reverse (so latest is at head of array)
    self.calls = [NSMutableArray array];
    self.missedCalls = [NSMutableArray array];
    NSEnumerator *e = [tmpCalls objectEnumerator];
    
    NSMutableArray *lastList = nil;
    Call *next;
    while (next = [e nextObject]) {
        // skip repeat contacts + call type
        if (lastList != nil && [lastList count] > 0) {
            Call *lastEnumeratedCall = [lastList objectAtIndex:0];
            if ([lastEnumeratedCall.name isEqualToString:next.name] 
                && [lastEnumeratedCall.type isEqualToNumber:next.type]) {
                // add this call to the current list
                [lastList addObject:next];
                continue;
            }            
        }

        // create an list of calls
        NSMutableArray *list = [NSMutableArray arrayWithObject:next];
        
        // add to main list
        [self.calls addObject:list];
        
        // if missed call add missed call list
        if ([next.type intValue] == CallTypeMissed) {
            [self.missedCalls addObject:list];
        }
        
        // remember last looked at call log
        lastList = list;
    }
    
    // force redraw of call log view
    [tableView reloadData];
}

#pragma mark Utility methods

- (NSArray*)listAtIndex:(NSIndexPath*)indexPath
{
    // get item reference in current call source
    NSMutableArray *src = (isFiltered == YES ? missedCalls : calls);
    
    // return list of calls for entry at index
    NSArray *list = [src objectAtIndex:indexPath.row];
    return list;
}

#pragma mark UITableViewDelegate methods

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tv {
    return 1;
}

- (NSInteger)tableView:(UITableView*)tv
 numberOfRowsInSection:(NSInteger)section {
    return (isFiltered ? [missedCalls count] : [calls count]);
}

- (UITableViewCell*)tableView:(UITableView*)tv
         cellForRowAtIndexPath:(NSIndexPath*)indexPath 
{
    // Set up the cell...
    NSArray *list = [self listAtIndex:indexPath];
    Call *info = [list objectAtIndex:0];
    NSUInteger count = [list count];

    BOOL isMissedCall = [info.type intValue] == CallTypeMissed;
    NSString *cellType = (isMissedCall ? MissedCellIdentifier : CellIdentifier);

    CallLogCell *cell = [tv dequeueReusableCellWithIdentifier:cellType];
    if (cell == nil) {
        cell = [[CallLogCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:cellType];
    }
    
    // default to using specified name
    NSString *suffix = @"";
	NSString *label = @"unknown";
    NSString *base = info.name;
    if (count > 1) {
        suffix = [NSString stringWithFormat:@" (%u)", count];
    }

    // if contact info specified try using that as the name
    if (info.contact != nil) {
        // get match results from address book search
        Contact *contact = info.contact;
        
        ABRecordID pid = [contact.contactID integerValue];
        ABMultiValueIdentifier mvid = [contact.valueID integerValue];
        if (pid != kABRecordInvalidID && mvid != kABMultiValueInvalidIdentifier) {
            // find name and phone label type
            ABRecordRef person = ABAddressBookGetPersonWithRecordID(addressBook, pid);
            if (person != NULL) {
                // ABMultiValueRef mv = ABRecordCopyValue(person, kABPersonPhoneProperty);
                // NSInteger index = ABMultiValueGetIndexForIdentifier(mv, mvid);
                NSString *compositeName = (__bridge_transfer NSString *)ABRecordCopyCompositeName(person);
                base = compositeName;
				label = [PhoneNumber labelFrom:pid property:mvid];
            }
        }
    }
	
    cell.nameTextField.text = [NSString stringWithFormat:@"%@%@", base, suffix];
	
    if ([info.type intValue] == CallTypeMissed) {
        cell.nameTextField.textColor = [UIColor redColor];
    }
	
    cell.timeTextField.text = [self relativeTime:info.start];
	cell.labelTextField.text = label;
    cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
	
    return cell;
}

- (void)tableView:(UITableView*)tv 
        commitEditingStyle:(UITableViewCellEditingStyle)editingStyle 
        forRowAtIndexPath:(NSIndexPath*)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSArray *list = [self listAtIndex:indexPath];

        // one of these should fail (already done)
        [missedCalls removeObject:list];
        [calls removeObject:list];
        
        // remove calls from manage object context
        NSEnumerator *e = [list objectEnumerator];
        Call *callToDelete = nil;
        while (callToDelete = [e nextObject]) {
            [managedObjectContext deleteObject:callToDelete];
        }
        
        // remove call from the table view
        [tv deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
              withRowAnimation:(UITableViewRowAnimation)UITableViewRowAnimationBottom];
    }
}

- (void)tableView:(UITableView *)tableView 
    accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    // get call from selection
    NSArray *list = [self listAtIndex:indexPath];
    [self performSegueWithIdentifier:@"PushCallDetails" sender:list];
}

- (void)tableView:(UITableView *)tv
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // deselect the row
    [tv deselectRowAtIndexPath:indexPath animated:YES];

    // get call from selection
    NSArray *list = [self listAtIndex:indexPath];
    Call *call = [list objectAtIndex:0];
    
    // now call contact from selection
    [[AppDelegate sharedAppDelegate] call:call.name withNumber:call.phoneNumber];
}

#pragma mark CallLog buttons

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    
    // only commit changes when leaving edit mode
    if (!editing)
        [self.managedObjectContext save:nil];

    // toggle Clear button display (depends on whether editing or not)
    if (editing == YES) {
        // add edit button for recent call list
        UIBarButtonItem *clearButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Clear" 
                                                                            style:UIBarButtonItemStylePlain 
                                                                           target:self 
                                                                           action:@selector(clearButtonClicked:)];
        self.navigationItem.leftBarButtonItem = clearButtonItem;
    } else {
        self.navigationItem.leftBarButtonItem = nil;
    }
}

#pragma mark Title Bar buttons

-(void)segmentAction:(id)sender {
    UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
    self.isFiltered = (segmentedControl.selectedSegmentIndex == 1 ? YES : NO);
    [tableView reloadData];
}

- (IBAction)clearButtonClicked:(id)sender {
    // end edit mode
    [self setEditing:NO animated:YES];

    // load initial call list
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription
                                   entityForName:@"Call" 
                                   inManagedObjectContext:managedObjectContext];
    [fetchRequest setEntity:entity];
    
    NSError *error;
    NSArray *all = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error != NULL) return;
    
    // remove all call log entries
    for (Call *call in all) {
        [managedObjectContext deleteObject:call];
    }
    
    self.calls = [NSMutableArray array];
    self.missedCalls = [NSMutableArray array];

    // clear missed call badges and stored value
    [[NSUserDefaults standardUserDefaults] setInteger:0 
                                               forKey:@"MissedCalls"];

    // commit changes
    [managedObjectContext save:NULL];
}

#pragma mark Segue methods

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSString *identifier = [segue identifier];
    
    if ([identifier isEqualToString:@"PushCallDetails"]) {
        CallDetailsViewController *cdvc = [segue destinationViewController];
        cdvc.calls = (NSArray*)sender;
    }
}

#pragma mark Date formatters

-(NSString *)relativeTime:(NSDate*)aDate
{
    // NSDate *aDate = [NSDate dateWithTimeIntervalSince1970:datetimestamp];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    unsigned int unitFlags =  NSYearCalendarUnit|NSMonthCalendarUnit|NSWeekCalendarUnit|NSWeekdayOrdinalCalendarUnit|NSWeekdayCalendarUnit|NSDayCalendarUnit|NSHourCalendarUnit|NSMinuteCalendarUnit;
    NSDateComponents *messageDateComponents = [calendar components:unitFlags fromDate:aDate];
    NSDateComponents *todayDateComponents = [calendar components:unitFlags fromDate:[NSDate date]];
    
    NSUInteger dayOfYearForMessage = [calendar ordinalityOfUnit:NSDayCalendarUnit inUnit:NSYearCalendarUnit forDate:aDate];
    NSUInteger dayOfYearForToday = [calendar ordinalityOfUnit:NSDayCalendarUnit inUnit:NSYearCalendarUnit forDate:[NSDate date]];
    
    NSString *dateString;
    if ([messageDateComponents year] == [todayDateComponents year] && 
        [messageDateComponents month] == [todayDateComponents month] &&
        [messageDateComponents day] == [todayDateComponents day]) 
    {
        dateString = [dateFormatter stringFromDate:aDate];
    } else if ([messageDateComponents year] == [todayDateComponents year] && 
               dayOfYearForMessage == (dayOfYearForToday-1)) {
        dateString = @"Yesterday";
    } else if ([messageDateComponents year] == [todayDateComponents year] &&
               dayOfYearForMessage > (dayOfYearForToday-6)) {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"EEEE"];
        dateString = [df stringFromDate:aDate];
    } else {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"yy"];
        dateString = [NSString stringWithFormat:@"%02d/%02d/%@", [messageDateComponents day], [messageDateComponents month], [df stringFromDate:aDate]];
    }
    
    return dateString;
}

@end
