//
//  NSMutableString+AddText.m
//  Locations
//
//  Created by 陈旭 on 5/25/15.
//  Copyright (c) 2015 陈旭. All rights reserved.
//

#import "NSMutableString+AddText.h"

@implementation NSMutableString (AddText)

- (void)addText:(NSString *)text
  withSeparator:(NSString *)separator
{
    if (text != nil) {
        if ([self length] > 0) {
            [self appendString:separator];
        }
        [self appendString:text];
    }
}

@end
