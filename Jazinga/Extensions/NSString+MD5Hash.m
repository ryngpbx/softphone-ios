//
//  NSString+MD5Addition.m
//  UIDeviceAddition
//
//  Created by Georg Kitz on 20.08.11.
//  Copyright 2011 Aurora Apps. All rights reserved.
//

#import "NSString+MD5Hash.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSString(MD5HashAdditions)

- (NSString *)MD5String
{
	if (![self length])
	{
		return nil;
	}
	
	const char *value = [self UTF8String];
	
	unsigned char outputBuffer[CC_MD5_DIGEST_LENGTH];
	CC_MD5(value, strlen(value), outputBuffer);
	
	NSMutableString *outputString = [[NSMutableString alloc] initWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
	
	for(NSInteger count = 0; count < CC_MD5_DIGEST_LENGTH; count++)
	{
		[outputString appendFormat:@"%02x",outputBuffer[count]];
	}
	
	return outputString;
}

@end
