//
//  ZKCrash.m
//  ZKHotFix
//
//  Created by 刘子康 on 2020/10/9.
//  Copyright © 2020 liuzikang. All rights reserved.
//

#import "ZKCrash.h"

@implementation ZKCrash

- (void)instanceMethodMightCrash:(id)object {
    NSMutableArray *array = [NSMutableArray array];
    [array addObject:object];
    NSLog(@"object = %@", object);
}

- (id)instanceMethodReturnMightCrash {
    return nil;
}

@end
