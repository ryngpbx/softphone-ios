//
//  Extension.h
//  Jazinga
//
//  Created by John Mah on 2013-03-29.
//  Copyright (c) 2013 Jazinga. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Extension : NSObject

@property (strong,nonatomic) NSString *name;
@property (strong,nonatomic) NSString *phoneNumber;

+ (Extension*)extensionWithName:(NSString*)n phoneNumber:(NSString*)pn;

- (id)initWithName:(NSString*)n phoneNumber:(NSString*)pn;

@end
