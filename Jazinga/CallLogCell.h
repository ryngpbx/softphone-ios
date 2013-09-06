//
//  CallLogCell.h
//  Jazinga
//
//  Created by John Mah on 2013-01-30.
//  Copyright (c) 2013 Jazinga. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CallLogCell : UITableViewCell

@property (strong, nonatomic) IBOutlet UILabel *nameTextField;
@property (strong, nonatomic) IBOutlet UILabel *labelTextField;
@property (strong, nonatomic) IBOutlet UILabel *timeTextField;

@end
