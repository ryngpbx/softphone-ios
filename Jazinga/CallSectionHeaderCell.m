//
//  CallSectionHeaderCell.m
//  Jazinga
//
//  Created by John Mah on 2012-08-01.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import "CallSectionHeaderCell.h"

@implementation CallSectionHeaderCell
@synthesize type;
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
