//
//  UIImage+Resize.m
//  Locations
//
//  Created by 陈旭 on 5/25/15.
//  Copyright (c) 2015 陈旭. All rights reserved.
//

#import "UIImage+Resize.h"

@implementation UIImage (Resize)

- (UIImage *)resizedImageWithBounds:(CGSize)bounds
{
    //This method first calculates how big the image can be in order to fit inside the bounds rectangle. It uses the “aspect fill” approach to keep the aspect ratio intact.
    CGFloat horizontalRatio = bounds.width / self.size.width;
    CGFloat verticalRatio = bounds.height / self.size.height;
    CGFloat ratio = MAX(horizontalRatio, verticalRatio);
    CGSize newSize = CGSizeMake(self.size.width * ratio, self.size.height * ratio);
    
    //Then it creates a new image context and draws the image into that.
    UIGraphicsBeginImageContextWithOptions(bounds, YES, 0);
    CGFloat x;
    CGFloat y;
    
    if (horizontalRatio <= verticalRatio) {
        x = - (self.size.width * ratio - bounds.width) / 2 ;
        y = 0;
    }else{
        x = 0;
        y = - (self.size.height *ratio - bounds.height) / 2;
    }
    [self drawInRect:CGRectMake(x, y, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

@end
