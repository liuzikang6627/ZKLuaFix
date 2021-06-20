//
//  ZKFix.h
//  ZKHotFix
//
//  Created by liuzikang on 2018/4/23.
//  Copyright © 2018年 liuzikang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZKLuaFix : NSObject

+ (void)fixIt;
+ (void)eval:(NSString *)string;

@end
