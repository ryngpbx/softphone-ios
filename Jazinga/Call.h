//
//  Call.h
//  Jazinga
//
//  Created by John Mah on 12-07-13.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "Contact.h"

@class Contact;

@interface Call : NSManagedObject

enum {
    CallTypeInbound = 0,
    CallTypeOutbound = 1,
    CallTypeMissed = 2,
    CallTypeDeclined = 3,
    CallTypeConference = 4,
    CallTypeRecordGreeting = 5
};
typedef NSUInteger CallType;

@property (nonatomic, retain) NSDate * end;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * phoneNumber;
@property (nonatomic, retain) NSDate * start;
@property (nonatomic, retain) NSNumber * type;
@property (nonatomic, retain) Contact *contact;

@end
