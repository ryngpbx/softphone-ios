//
//  PhoneNumber.m
//  Jazinga Softphone
//
//  Created by John Mah on 12-07-04.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import "PhoneNumber.h"
#import <AddressBook/AddressBook.h>

@implementation PhoneNumber

static __strong NSArray *people;
static ABAddressBookRef addressBook;
static NSMutableDictionary *matches;

+ (void)preload {
    // preload the address book
    addressBook = ABAddressBookCreate();
    ABAddressBookRegisterExternalChangeCallback(addressBook, addressBookExternalChangeCallback, NULL);

    // force recache before registering for change first
    addressBookRecache();
}

void addressBookRecache() {
    // check for no access
    if (addressBook == NULL) return;

    // check for address book access first?
    CFIndex count = ABAddressBookGetPersonCount(addressBook);
    if (count == kCFNotFound) return;

    people = (__bridge_transfer NSArray *)ABAddressBookCopyArrayOfAllPeople(addressBook);
    matches = [NSMutableDictionary dictionaryWithCapacity:count];
    
    @autoreleasepool {
        // iterate over list of people
        for (id record in people) {
            ABRecordRef person = (__bridge ABRecordRef)record;
            ABRecordID pid = ABRecordGetRecordID(person);
            ABMultiValueRef values = ABRecordCopyValue(person, kABPersonPhoneProperty);        
            
            // search array for existing phone numbers
            for (int i = 0, last = ABMultiValueGetCount(values); i < last; i++) {
                // next phone number
                NSString *currPhoneNumber = (__bridge_transfer NSString*)ABMultiValueCopyValueAtIndex(values, i);
                NSString *normalized = [PhoneNumber normalize:currPhoneNumber];
                
                // get id's for values
                ABMultiValueIdentifier mvid = ABMultiValueGetIdentifierAtIndex(values, i);
                NSDictionary *matched = [NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithInteger:pid],@"contactID", 
                                         [NSNumber numberWithInteger:mvid], @"valueID",
                                         nil];
                
                // cache good match
                [matches setObject:matched forKey:normalized];
            }
            
            CFRelease(values);
        }
    }
}

static void addressBookExternalChangeCallback(ABAddressBookRef ab,
                                         CFDictionaryRef info,
                                         void *context)
{
    // only handle updates to the default address book
    if (ab != addressBook) return;
    
    // copy over the people again
    if (addressBook)
        CFRelease(addressBook);
    
    addressBook = ABAddressBookCreate();
    addressBookRecache();
}
                                                
+ (NSString*)normalize:(NSString*)number {
    // acceptable phone digits for comparison purposes
    NSMutableCharacterSet *accepted = [NSMutableCharacterSet decimalDigitCharacterSet];
    [accepted addCharactersInString:@"+*#"];
    
    return [[number componentsSeparatedByCharactersInSet:[accepted invertedSet]] componentsJoinedByString:@""];
}

+ (NSString*)format:(NSString*)number {
    // format the normalized version of the number
    NSString *normalized = [PhoneNumber normalize:number];
    NSUInteger len = normalized.length;
    
    // don't bother unless we have at least two-digits
    if (len < 3) return normalized;
    
    /*
     NSString prefix = [normalized substringToIndex:3];
     if ([prefix compare:@"011"] == NSOrderedSame) {
     
     } else if ([prefix compare:@"+44"]
     */
    
    // numbers greater then 12 charactes are left unformatted
    if (len > 10 || len < 4) 
        return normalized;
    
    NSString *formatted = number;
    
    // format into XXX-X[...]
    if (len > 3 && len <= 7) {
        formatted = [NSString stringWithFormat:@"%@-%@", [normalized substringToIndex:3],
                     [normalized substringFromIndex:3], nil];
    } else if (len > 7 && len < 13) {
        NSRange middle = { 3, 3 };
        formatted = [NSString stringWithFormat:@"(%@) %@-%@", [normalized substringToIndex:3],
                     [normalized substringWithRange:middle], [normalized substringFromIndex:6],nil]; 
    }
    
    return formatted;
}

+ (NSDictionary*)match:(NSString*)contactNumber
{
    // trivial error check
    if (contactNumber == nil || [contactNumber length] <= 0) return nil;

    // use normalized version of contact number
    NSString *pn = [PhoneNumber normalize:contactNumber];

    // check for known good match
    NSDictionary *found = [matches objectForKey:pn];
    if (found != nil) return found;

    return nil;
}

+ (NSString*)numberFrom:(ABRecordID)pid 
               property:(ABPropertyID)mvid
{
    if (pid == kABRecordInvalidID 
        || mvid == kABMultiValueInvalidIdentifier) return nil;
    
    // find name and phone label type
    ABRecordRef person = ABAddressBookGetPersonWithRecordID(addressBook, pid);
    ABMultiValueRef mv = ABRecordCopyValue(person, kABPersonPhoneProperty);
    NSInteger index = ABMultiValueGetIndexForIdentifier(mv, mvid);
    CFStringRef currPhoneLabel = ABMultiValueCopyValueAtIndex(mv, index);
    
    // release copies
    CFRelease(mv);

    return [NSString stringWithString:(__bridge_transfer NSString*)currPhoneLabel];
}

+ (NSString*)labelFrom:(ABRecordID)pid
               property:(ABPropertyID)mvid
{
    if (pid == kABRecordInvalidID
        || mvid == kABMultiValueInvalidIdentifier) return nil;
    
    // find name and phone label type
    ABRecordRef person = ABAddressBookGetPersonWithRecordID(addressBook, pid);
    ABMultiValueRef mv = ABRecordCopyValue(person, kABPersonPhoneProperty);
    NSInteger index = ABMultiValueGetIndexForIdentifier(mv, mvid);
    CFStringRef currPhoneLabel = ABMultiValueCopyLabelAtIndex(mv, index);
    
    // release copies
    CFRelease(mv);
	
    return [NSString stringWithString:(__bridge_transfer NSString*)ABAddressBookCopyLocalizedLabel(currPhoneLabel)];
}

@end
