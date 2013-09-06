//
//  SIPCallDetails.h
//  Jazinga Softphone
//
//  Created by John Mah on 12-07-03.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AddressBook/ABRecord.h>
#import <pjsua-lib/pjsua.h>
#import "pjsua_app.h"
#import <pj/types.h>
#import "Call.h"

@interface SIPCallDetails : NSObject

@property pjsua_call_id callID;
@property CallType type;
@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *phoneNumber;

@property (nonatomic) ABRecordID contactID;
@property (nonatomic) ABPropertyID propertyID;

+ (id)withCallID:(pjsua_call_id)cid type:(CallType)type;
+ (id)withCallID:(pjsua_call_id)cid type:(CallType)type name:(NSString*)cname number:(NSString*)cnumber;
+ (NSString*)parseSipDisplayName:(NSString*)sipDisplayName;
+ (NSString*)parseSipCallerNumber:(NSString*)sipCallerNumber;

- (id)initWithCallID:(pjsua_call_id)cid type:(CallType)type name:(NSString*)cname number:(NSString*)cnumber;
- (NSString*)callerDisplay;

@end
