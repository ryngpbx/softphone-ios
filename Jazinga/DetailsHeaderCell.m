//
//  DetailsHeaderCell.m
//  Jazinga
//
//  Created by John Mah on 2012-07-31.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import "DetailsHeaderCell.h"
#import <QuartzCore/QuartzCore.h>

@implementation DetailsHeaderCell

@synthesize name;
@synthesize image;

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

- (void)setContact:(ABRecordID)cid
{
    ABAddressBookRef addressBook = ABAddressBookCreate();
    ABRecordRef person = ABAddressBookGetPersonWithRecordID(addressBook, cid);
        
    if (person != NULL && ABPersonHasImageData(person) == YES) {
        NSData *data = (__bridge_transfer NSData*) ABPersonCopyImageData(person);
        if (data != nil) {
            image.image = [UIImage imageWithData:data];
            image.layer.borderColor = [UIColor darkGrayColor].CGColor;
            image.layer.borderWidth = 1.0;
            image.layer.cornerRadius = 3.0;
        }
    }
    
    CFRelease(addressBook);
}

- (void)cacheImage:(UIImage*)img
{
    image.image = img;
    image.layer.borderColor = [UIColor darkGrayColor].CGColor;
    image.layer.borderWidth = 1.0;
    image.layer.cornerRadius = 3.0;
}

@end
