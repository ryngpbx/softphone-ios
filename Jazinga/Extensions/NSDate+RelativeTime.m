//
//  NSDate+RelativeTime.m
//  Jazinga
//
//  Created by John Mah on 2012-08-01.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import "NSDate+RelativeTime.h"


@implementation NSDate (RelativeTime)

- (NSString *)relativeTime
{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    unsigned int unitFlags =  NSYearCalendarUnit|NSMonthCalendarUnit|NSWeekCalendarUnit|NSWeekdayOrdinalCalendarUnit|NSWeekdayCalendarUnit|NSDayCalendarUnit|NSHourCalendarUnit|NSMinuteCalendarUnit;
    NSDateComponents *messageDateComponents = [calendar components:unitFlags fromDate:self];
    NSDateComponents *todayDateComponents = [calendar components:unitFlags fromDate:[NSDate date]];
    
    NSUInteger dayOfYearForMessage = [calendar ordinalityOfUnit:NSDayCalendarUnit inUnit:NSYearCalendarUnit forDate:self];
    NSUInteger dayOfYearForToday = [calendar ordinalityOfUnit:NSDayCalendarUnit inUnit:NSYearCalendarUnit forDate:[NSDate date]];
    
    NSString *dateString;
    if ([messageDateComponents year] == [todayDateComponents year] &&
        [messageDateComponents month] == [todayDateComponents month] &&
        [messageDateComponents day] == [todayDateComponents day])
    {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"h:mm a"];
        dateString = [dateFormatter stringFromDate:self];
    } else if ([messageDateComponents year] == [todayDateComponents year] &&
               dayOfYearForMessage == (dayOfYearForToday-1)) {
        dateString = @"Yesterday";
    } else if ([messageDateComponents year] == [todayDateComponents year] &&
               dayOfYearForMessage > (dayOfYearForToday-6)) {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"EEEE"];
        dateString = [df stringFromDate:self];
    } else {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"yy"];
        dateString = [NSString stringWithFormat:@"%02d/%02d/%@", [messageDateComponents day], [messageDateComponents month], [df stringFromDate:self]];
    }
    
    return dateString;
}

#define PLURALITY(x)    (x == 1 ? "" : "s")

- (NSString*)durationEndingAt:(NSDate*)finishDate
{
    // get current time
    NSTimeInterval callTimeSoFar = -[self timeIntervalSinceDate:finishDate];
    
    // interpret seconds to hh:mm:ss format
    NSUInteger hours = callTimeSoFar / 3600;
    NSUInteger mins = ((NSUInteger)callTimeSoFar - (hours * 3600)) / 60;
    NSUInteger secs = ((NSUInteger)callTimeSoFar - (hours * 3600) - (mins * 60));
    
    // set the call duration text
    NSString *duration = [NSString stringWithFormat:@"%u hour%s %u min%s", hours,
                          PLURALITY(hours), mins, PLURALITY(mins)];
    if (hours == 0) {
        if (mins == 0) {
            duration = [NSString stringWithFormat:@"%u second%s", secs, PLURALITY(secs)];
        } else {
            duration = [NSString stringWithFormat:@"%u minute%s", mins, PLURALITY(mins)];
        }
    }

    return duration;
}

- (BOOL)isSameDay:(NSDate*)date
{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    unsigned int unitFlags =  NSYearCalendarUnit|NSMonthCalendarUnit|NSWeekCalendarUnit|NSWeekdayOrdinalCalendarUnit|NSWeekdayCalendarUnit|NSDayCalendarUnit|NSHourCalendarUnit|NSMinuteCalendarUnit;
    NSDateComponents *messageDateComponents = [calendar components:unitFlags fromDate:self];
    NSDateComponents *todayDateComponents = [calendar components:unitFlags fromDate:date];
    
    return ([messageDateComponents year] == [todayDateComponents year]
            && [messageDateComponents month] == [todayDateComponents month]
            && [messageDateComponents day] == [todayDateComponents day]);
}

@end
