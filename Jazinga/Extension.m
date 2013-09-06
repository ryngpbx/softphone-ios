//
//  Extension.m
//  Jazinga
//
//  Created by John Mah on 2013-03-29.
//  Copyright (c) 2013 Jazinga. All rights reserved.
//

#import "Extension.h"

@implementation Extension

@synthesize name;
@synthesize phoneNumber;

+ (Extension*)extensionWithName:(NSString*)n phoneNumber:(NSString*)pn
{
	return [[Extension alloc] initWithName:n phoneNumber:pn];
}

- (id)initWithName:(NSString*)n phoneNumber:(NSString*)pn
{
	if (self = [super init]) {
		self.name = n;
		self.phoneNumber = pn;
	}
	return self;
}

@end
