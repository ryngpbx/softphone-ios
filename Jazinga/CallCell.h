//
//  CallCell.h
//  Jazinga
//
//  Created by John Mah on 2012-08-01.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CallCell : UITableViewCell

@property (strong, nonatomic) IBOutlet UILabel *time;
@property (strong, nonatomic) IBOutlet UILabel *duration;
@property (strong, nonatomic) IBOutlet UILabel *date;

@end
