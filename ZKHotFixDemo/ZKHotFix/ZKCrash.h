//
//  ZKCrash.h
//  ZKHotFix
//
//  Created by 刘子康 on 2020/10/9.
//  Copyright © 2020 liuzikang. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZKCrash : NSObject

- (void)instanceMethodMightCrash:(id)object;

- (id)instanceMethodReturnMightCrash;

@end

NS_ASSUME_NONNULL_END
