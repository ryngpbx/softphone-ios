//
//  DetailsHeaderCell.h
//  Jazinga
//
//  Created by John Mah on 2012-07-31.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>

@interface DetailsHeaderCell : UITableViewCell

@property (strong, nonatomic) IBOutlet UILabel *name;
@property (strong, nonatomic) IBOutlet UIImageView *image;

- (void)setContact:(ABRecordID)cid;
- (void)cacheImage:(UIImage*)image;

@end
