//
//  Contact.h
//  Jazinga
//
//  Created by John Mah on 12-07-13.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Contact : NSManagedObject

@property (nonatomic, retain) NSNumber *contactID;
@property (nonatomic, retain) NSNumber *valueID;
@property (nonatomic, retain) NSManagedObject *call;

@end
