//
//  SIPCallDetails.m
//  Jazinga Softphone
//
//  Created by John Mah on 12-07-03.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import "SIPCallDetails.h"
#import <Foundation/NSRegularExpression.h>

@implementation SIPCallDetails

@synthesize callID;
@synthesize type;
@synthesize name;
@synthesize phoneNumber;
@synthesize contactID;
@synthesize propertyID;

+ (id)withCallID:(pjsua_call_id)cid type:(CallType)type
{
    NSString *callerDisplay = nil;
    NSString *callerNumber = nil;
    
    struct pjsua_call_info info;
    memset(&info, 0, sizeof(info));
    pj_status_t status = pjsua_call_get_info(cid, &info);
    if (status == PJ_SUCCESS) {
        NSString *sipCallerNumber = nil;
        if (info.remote_contact.slen > 0) {
            [NSString stringWithCString:pj_strbuf(&info.remote_contact)
                               encoding:NSUTF8StringEncoding];
            if (sipCallerNumber != nil)
                callerNumber = [SIPCallDetails parseSipCallerNumber:sipCallerNumber];
        }

        NSString *sipDisplayName = nil;
        if (info.remote_info.slen > 0) {
            [NSString stringWithCString:pj_strbuf(&info.remote_info) encoding:NSUTF8StringEncoding];
            if (sipDisplayName != nil)
                callerDisplay = [SIPCallDetails parseSipDisplayName:sipDisplayName];
        }
    }

    return [SIPCallDetails withCallID:cid
                                 type:type
                                 name:callerDisplay
                               number:callerNumber];
}

+ (id)withCallID:(pjsua_call_id)cid type:(CallType)type name:(NSString*)cname number:(NSString*)cnumber
{
    return [[self alloc] initWithCallID:cid type:type name:cname number:cnumber];
}

- (id)initWithCallID:(pjsua_call_id)cid type:(CallType)ctype name:(NSString*)cname number:(NSString *)cnumber
{
    if (self = [super init]) {
        self.callID = cid;
        self.type = ctype;
        self.name = cname;
        self.phoneNumber = cnumber;
    }
    return self;
}

+ (NSString*)parseSipDisplayName:(NSString*)string {
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^\"(.*)\" (.*)"
                                                                           options:NSRegularExpressionCaseInsensitive | NSRegularExpressionAnchorsMatchLines
                                                                             error:&error];
    NSArray *matches = [regex matchesInString:string
                                      options:0
                                        range:NSMakeRange(0, [string length])];
    for (NSTextCheckingResult *match in matches) {
        NSRange nameMatch = [match rangeAtIndex:1];
        NSString *name = [string substringWithRange:nameMatch];
        // NSRange sipMatch = [match rangeAtIndex:2];
        // NSString *second = [string substringWithRange:sipMatch];
        
        return name;
    }    
    return @"Unknown";
}

+ (NSString*)parseSipCallerNumber:(NSString*)string {
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^<sip:(.*)(@)(.*)(;transport=TCP)>"
                                                                           options:NSRegularExpressionCaseInsensitive | NSRegularExpressionAnchorsMatchLines
                                                                             error:&error];
    NSArray *matches = [regex matchesInString:string
                                      options:0
                                        range:NSMakeRange(0, [string length])];
    for (NSTextCheckingResult *match in matches) {
        NSRange nameMatch = [match rangeAtIndex:1];
        NSString *name = [string substringWithRange:nameMatch];
        // NSRange sipMatch = [match rangeAtIndex:2];
        // NSString *second = [string substringWithRange:sipMatch];
        
        return name;
    }    
    return @"Unknown";
}

- (NSString*)callerDisplay {
    // use supplied contact name if present
    if (name != nil && [name length] > 0) 
        return self.name;
    
    // next try supplied phone number
    if (phoneNumber != nil && [phoneNumber length] > 0) 
        return self.phoneNumber;
    
    // next use SIP call info to get name
    NSString *callerDisplay = @"Unknown";
    if (callID == -1) 
        return callerDisplay;

    struct pjsua_call_info info;
    memset(&info, 0, sizeof(info));
    pj_status_t status = pjsua_call_get_info(callID, &info);

    if (status == PJ_SUCCESS && info.remote_info.slen > 0) {
        NSString *sipName = [NSString stringWithCString:pj_strbuf(&info.remote_info)
                                               encoding:NSUTF8StringEncoding];
        callerDisplay = [SIPCallDetails parseSipDisplayName:sipName];
    }

    return callerDisplay;
}

@end
