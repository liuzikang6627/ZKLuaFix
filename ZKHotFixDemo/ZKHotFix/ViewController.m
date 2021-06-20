//
//  ViewController.m
//  ZKHotFix
//
//  Created by liuzikang on 2018/4/23.
//  Copyright © 2018年 liuzikang. All rights reserved.
//

#import "ViewController.h"
#import "ZKCrash.h"
#import "ZKLuaFix.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self makeCrash];
    NSLog(@"===================");
}


#pragma mark - makecrash
- (void)makeCrash {
    // 激活使用热更修复bug
    [ZKLuaFix fixIt];
    
    // 加载js文件
    NSString *jsPath = [[NSBundle mainBundle] pathForResource:@"HotFix.lua" ofType:nil];
    NSString *jsString = [NSString stringWithContentsOfFile:jsPath encoding:NSUTF8StringEncoding error:nil];
    [ZKLuaFix eval:jsString];
    
    // 闪退: 数组新增nil
    [self instanceMethodCrash];
    
    // 闪退: 返回值nil
    [self instanceMethodReturnCrash];
}

+ (void)runClassMethod {
    NSLog(@"run a class method");
}

- (id)runInstanceMethod:(NSString*)a b:(NSString*)b {
    NSLog(@"run a instance method");
    return [NSString stringWithFormat:@"%@%@", a, b];
}

- (int)runInstanceMethodGetInt {
    return 10;
}

#pragma mark - Fix
- (void)instanceMethodCrash {
    ZKCrash *crash = [ZKCrash new];
    [crash instanceMethodMightCrash:nil];
    NSLog(@"not crash~~");
}

- (void)instanceMethodReturnCrash {
    ZKCrash *crash = [ZKCrash new];
    NSMutableArray *array = [NSMutableArray array];
    id object = [crash instanceMethodReturnMightCrash];
    [array addObject:object];
    NSLog(@"array = %@", array);
    NSLog(@"not crash~~");
}

@end
