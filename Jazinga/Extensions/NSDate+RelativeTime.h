//
//  NSDate+RelativeTime.h
//  Jazinga
//
//  Created by John Mah on 2012-08-01.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (RelativeTime)

- (NSString*)relativeTime;
- (NSString*)durationEndingAt:(NSDate*)finishDate;

- (BOOL)isSameDay:(NSDate*)date;

@end
