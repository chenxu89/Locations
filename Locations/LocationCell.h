//
//  LocationCell.h
//  Locations
//
//  Created by 陈旭 on 5/23/15.
//  Copyright (c) 2015 陈旭. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LocationCell : UITableViewCell

@property (nonatomic, weak) IBOutlet UILabel *descriptionLabel;
@property (nonatomic, weak) IBOutlet UILabel *addressLabel;
@property (weak, nonatomic) IBOutlet UIImageView *photoImageView;

@end
