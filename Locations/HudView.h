//
//  HudView.h
//  Locations
//
//  Created by 陈旭 on 5/22/15.
//  Copyright (c) 2015 陈旭. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HudView : UIView

+ (instancetype)hudInView:(UIView *)view
                 animated:(BOOL)animated;

@property (nonatomic, strong) NSString *text;

@end
