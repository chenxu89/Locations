//
//  MyTabBarController.m
//  Locations
//
//  Created by 陈旭 on 5/26/15.
//  Copyright (c) 2015 陈旭. All rights reserved.
//

#import "MyTabBarController.h"

@implementation MyTabBarController

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (UIViewController *)childViewControllerForStatusBarStyle
{
    return nil;
}

@end
