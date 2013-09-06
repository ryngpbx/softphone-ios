//
//  PhoneNumber.h
//  Jazinga Softphone
//
//  Created by John Mah on 12-07-04.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>

@interface PhoneNumber : NSObject

+ (void)preload;
+ (NSString*)normalize:(NSString*)number;
+ (NSString*)format:(NSString*)number;
+ (NSDictionary*)match:(NSString*)contactNumber;
+ (NSString*)numberFrom:(ABRecordID)recordID property:(ABPropertyID)propertyID;
+ (NSString*)labelFrom:(ABRecordID)recordID property:(ABPropertyID)propertyID;

@end
