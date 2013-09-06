//
//  NSString+URLEncoding.m
//  Jazinga
//
//  Created by John Mah on 12-07-18.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import "NSString+URLEncoding.h"

@implementation NSString (URLEncoding)

-(NSString *)urlEncodeUsingEncoding:(NSStringEncoding)encoding {
    return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
                                                           (__bridge CFStringRef)self,
                                                           NULL,
                                                           (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
                                                           CFStringConvertNSStringEncodingToEncoding(encoding));
}

@end
