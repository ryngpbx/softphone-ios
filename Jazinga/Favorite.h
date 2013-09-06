//
//  Favorite.h
//  Jazinga
//
//  Created by John Mah on 12-07-24.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Favorite : NSManagedObject

@property (nonatomic, retain) NSNumber * contactID;
@property (nonatomic, retain) NSString * phoneNumber;
@property (nonatomic, retain) NSNumber * valueID;
@property (nonatomic, retain) NSNumber * order;

@end
