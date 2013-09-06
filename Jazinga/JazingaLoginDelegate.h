//
//  JazingaLoginDelegate.h
//  Jazinga Softphone
//
//  Created by John Mah on 12-06-26.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <pj/types.h>


@protocol JazingaLoginDelegate <NSObject>

-(void)authenticated;
-(void)authenticationFailedWithMessage:(NSString*)error;

@optional

-(void)didStartAuthentication;
-(void)didFinishAuthentication;

@end
