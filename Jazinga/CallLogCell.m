//
//  CallLogCell.m
//  Jazinga
//
//  Created by John Mah on 2013-01-30.
//  Copyright (c) 2013 Jazinga. All rights reserved.
//

#import "CallLogCell.h"

@implementation CallLogCell

@synthesize nameTextField;
@synthesize labelTextField;
@synthesize timeTextField;

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

    // Configure the view for the selected state
}

@end
