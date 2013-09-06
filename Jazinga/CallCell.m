//
//  CallCell.m
//  Jazinga
//
//  Created by John Mah on 2012-08-01.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import "CallCell.h"

@implementation CallCell

@synthesize time;
@synthesize duration;
@synthesize date;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
}

@end
