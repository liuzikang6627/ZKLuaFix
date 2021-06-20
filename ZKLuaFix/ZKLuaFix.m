//
//  ZKFix.m
//  ZKHotFix
//
//  Created by liuzikang on 2018/4/23.
//  Copyright © 2018年 liuzikang. All rights reserved.
//

#import "ZKLuaFix.h"
#import "Aspects.h"
#import "LuaScriptCore.h"
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIGeometry.h>
#import <objc/runtime.h>


#define zk_fixMethod                   @"fixMethod"
#define zk_setInvocationArgs           @"setInvocationArgs"
#define zk_setInvocationReturnValue    @"setInvocationReturnValue"
#define zk_runInvocation               @"runInvocation"
#define zk_runClassMethod              @"runClassMethod"
#define zk_runInstanceMethod           @"runInstanceMethod"


@implementation ZKLuaFix

+ (void)fixIt {
    LSCContext *context = [self context];
    // 修复指定方法
    // fixMethod(类名,方法名,选项:0-方法后/1-替换/2-方法前,是否类方法,匿名函数:实例+方法对象+方法传参数组)
    [context registerMethodWithName:zk_fixMethod block:^LSCValue *(NSArray<LSCValue *> *arguments) {
        NSString *instanceName = [arguments[0] toObject];
        NSString *selectorName = [arguments[1] toObject];
        AspectOptions options = [arguments[2] toInteger];
        BOOL isClassMethod = [arguments[3] toBoolean];
        LSCFunction *fixImpl = [arguments[4] toFunction];
        [self fixWithMethod:isClassMethod options:options instanceName:instanceName selectorName:selectorName fixImp:fixImpl];
        return nil;
    }];
    // 修改该方法传参
    // setInvocationArgs(方法对象,修改后的方法传参数组)
    [context registerMethodWithName:zk_setInvocationArgs block:^LSCValue *(NSArray<LSCValue *> *arguments) {
        NSInvocation *invocation = [arguments[0] toObject];
        NSArray *args = [arguments[1] toObject];
        [self setInvocationArgsWithInvocation:invocation arguments:args];
        return nil;
    }];
    // 修改该方法返回值
    // setInvocationReturnValue(方法对象,返回值)
    [context registerMethodWithName:zk_setInvocationReturnValue block:^LSCValue *(NSArray<LSCValue *> *arguments) {
        NSInvocation *invocation = [arguments[0] toObject];
        id returnValue = [arguments[1] toObject];
        [self setInvocationReturnValueWithInvocation:invocation value:returnValue];
        return nil;
    }];
    // 立刻调用该方法
    // runInvocation(方法对象)
    [context registerMethodWithName:zk_runInvocation block:^LSCValue *(NSArray<LSCValue *> *arguments) {
        NSInvocation *invocation = [arguments[0] toObject];
        [invocation invoke];
        return nil;
    }];

    // 调用+方法
    // runClassMethod(类名,方法名,传参数组)
    [context registerMethodWithName:zk_runClassMethod block:^LSCValue *(NSArray<LSCValue *> *arguments) {
        NSString * className = [arguments[0] toObject];
        NSString *selectorName = [arguments[1] toObject];
        NSArray *args = nil;
        if (arguments.count>2) {
            args = [arguments[2] toObject];
        }
        id result = [self runClassWithClassName:className selector:selectorName arguments:args];
        return [LSCValue objectValue:result];
    }];
    // 调用-方法
    // runClassMethod(实例类名,方法名,传参数组)
    [context registerMethodWithName:zk_runInstanceMethod block:^LSCValue *(NSArray<LSCValue *> *arguments) {
        NSString * className = [arguments[0] toObject];
        NSString *selectorName = [arguments[1] toObject];
        NSArray *args = nil;
        if (arguments.count>2) {
            args = [arguments[2] toObject];
        }
        id result = [self runInstanceWithInstance:className selector:selectorName arguments:args];
        return [LSCValue objectValue:result];
    }];

    // 打印log
    // print("Hello World");
    [context registerMethodWithName:@"print" block:^LSCValue *(NSArray<LSCValue *> *arguments) {
        NSLog(@"%@", [arguments[0] toString]);
        return nil;
    }];
}

+ (void)eval:(NSString *)string {
    if (  string == nil ||
          string == (id)[NSNull null] ||
        ![string isKindOfClass:[NSString class]]) return;

    [[self context] evalScriptFromString:string];
}

#pragma mark - Private
+ (LSCContext *)context {
    static LSCContext *context = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        context = [[LSCContext alloc] init];
        [context onException:^(NSString *message) {
            NSLog(@"#error = %@", message);
        }];
    });
    return context;
}

+ (void)fixWithMethod:(BOOL)isClassMethod options:(AspectOptions)options
         instanceName:(NSString *)instanceName selectorName:(NSString *)selectorName fixImp:(LSCFunction *)fixImpl {
    Class klass = NSClassFromString(instanceName);
    if (isClassMethod) {
        klass = object_getClass(klass);
    }

    SEL sel = NSSelectorFromString(selectorName);
    [klass aspect_hookSelector:sel withOptions:(AspectOptions)options usingBlock:^(id<AspectInfo> aspectInfo) {
        NSMutableArray *tmpArgs = [NSMutableArray array];
        for (id object in aspectInfo.arguments) {
            [tmpArgs addObject:[LSCValue objectValue:object]];
        }
        
        [fixImpl invokeWithArguments:@[[LSCValue objectValue:aspectInfo.instance],
                                       [LSCValue objectValue:aspectInfo.originalInvocation],
                                       [LSCValue arrayValue:tmpArgs.copy]]];
    } error:nil];
}

+ (void)setInvocationArgsWithInvocation:(NSInvocation *)invocation arguments:(NSArray *)arguments {
    [self setInv:invocation withSign:invocation.methodSignature andArgs:arguments];
}

+ (void)setInvocationReturnValueWithInvocation:(NSInvocation *)invocation value:(id)returnValue_obj {
#define SET_RETURN_VALUE_OBJ_TYPE_METHOD(type, method) \
else if(strcmp(returnType, @encode(type)) == 0) {\
        type result = [returnValue_obj method]; \
        [invocation setReturnValue:&result]; \
    }
#define SET_RETURN_VALUE_OBJ_TYPE(type) SET_RETURN_VALUE_OBJ_TYPE_METHOD(type, type ## Value)
    const char * returnType = invocation.methodSignature.methodReturnType;

    if(strcmp(returnType, @encode(id)) == 0) {
        [invocation setReturnValue:&returnValue_obj];
    } else if(strcmp(returnType, "?") == 0) {
        void * returnValuePointer = [returnValue_obj pointerValue];
        [invocation setReturnValue:&returnValuePointer];
    } else if(strcmp(returnType, "*") == 0) {
        void * returnValuePointer = [returnValue_obj pointerValue];
        [invocation setReturnValue:&returnValuePointer];
    } else if(strcmp(returnType, ":") == 0) {
        SEL returnValuePointer = [returnValue_obj pointerValue];
        [invocation setReturnValue:&returnValuePointer];
    }
    SET_RETURN_VALUE_OBJ_TYPE_METHOD(BOOL, boolValue)
    SET_RETURN_VALUE_OBJ_TYPE(bool)
    SET_RETURN_VALUE_OBJ_TYPE(char)
    SET_RETURN_VALUE_OBJ_TYPE(short)
    SET_RETURN_VALUE_OBJ_TYPE(int)
    SET_RETURN_VALUE_OBJ_TYPE(long)
    SET_RETURN_VALUE_OBJ_TYPE_METHOD(long long, longLongValue)
    SET_RETURN_VALUE_OBJ_TYPE_METHOD(unsigned char, unsignedCharValue)
    SET_RETURN_VALUE_OBJ_TYPE_METHOD(unsigned short, unsignedShortValue)
    SET_RETURN_VALUE_OBJ_TYPE_METHOD(unsigned int, unsignedIntValue)
    SET_RETURN_VALUE_OBJ_TYPE_METHOD(unsigned long, unsignedLongValue)
    SET_RETURN_VALUE_OBJ_TYPE_METHOD(unsigned long long, unsignedLongLongValue)
    SET_RETURN_VALUE_OBJ_TYPE(float)
    SET_RETURN_VALUE_OBJ_TYPE(double)
}

+ (id)runClassWithClassName:(NSString *)className selector:(NSString *)selector arguments:(NSArray *)arguments {
    Class klass = NSClassFromString(className);
    if (!klass) return nil;

    SEL sel = NSSelectorFromString(selector);
    if (!sel) return nil;

    if (![klass respondsToSelector:sel]) return nil;

    NSMethodSignature *signature = [klass methodSignatureForSelector:sel];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = sel;
    [self setInv:invocation withSign:signature andArgs:arguments];
    [invocation invokeWithTarget:klass];

    return [self getReturnFromInv:invocation withSign:signature];
}

+ (id)runInstanceWithInstance:(NSString *)className selector:(NSString *)selector arguments:(NSArray *)arguments {
    Class klass = NSClassFromString(className);
    if (!klass) return nil;

    SEL sel = NSSelectorFromString(selector);
    if (!sel) return nil;

    id instance = [[klass alloc] init];

    if (![instance respondsToSelector:sel]) return nil;

    NSMethodSignature *signature = [instance methodSignatureForSelector:sel];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = sel;
    [self setInv:invocation withSign:signature andArgs:arguments];
    [invocation invokeWithTarget:instance];

    return [self getReturnFromInv:invocation withSign:signature];
}

+ (id)getReturnFromInv:(NSInvocation *)inv withSign:(NSMethodSignature *)sign {
    NSUInteger length = [sign methodReturnLength];
    if (length == 0) return nil;

    char *type = (char *)[sign methodReturnType];
    while (*type == 'r' ||  // const
           *type == 'n' ||  // in
           *type == 'N' ||  // inout
           *type == 'o' ||  // out
           *type == 'O' ||  // bycopy
           *type == 'R' ||  // byref
           *type == 'V') {  // oneway
        type++; // cutoff useless prefix
    }

#define return_with_number(_type_) \
do { \
    _type_ ret; \
    [inv getReturnValue:&ret]; \
    return @(ret); \
} while(0)

    switch (*type) {
        case 'v': return nil; // void
        case 'B': return_with_number(bool);
        case 'c': return_with_number(char);
        case 'C': return_with_number(unsigned char);
        case 's': return_with_number(short);
        case 'S': return_with_number(unsigned short);
        case 'i': return_with_number(int);
        case 'I': return_with_number(unsigned int);
        case 'l': return_with_number(int);
        case 'L': return_with_number(unsigned int);
        case 'q': return_with_number(long long);
        case 'Q': return_with_number(unsigned long long);
        case 'f': return_with_number(float);
        case 'd': return_with_number(double);
        case 'D': { // long double
            long double ret;
            [inv getReturnValue:&ret];
            return [NSNumber numberWithDouble:ret];
        };

        case '@': { // id
            void *ret;
            [inv getReturnValue:&ret];
            return (__bridge id)(ret);
        };

        case '#' : { // Class
            Class ret = nil;
            [inv getReturnValue:&ret];
            return ret;
        };

        default: { // struct / union / SEL / void* / unknown
            const char *objCType = [sign methodReturnType];
            char *buf = calloc(1, length);
            if (!buf) return nil;
            [inv getReturnValue:buf];
            NSValue *value = [NSValue valueWithBytes:buf objCType:objCType];
            free(buf);
            return value;
        };
    }
#undef return_with_number
}

+ (void)setInv:(NSInvocation *)inv withSign:(NSMethodSignature *)sign andArgs:(NSArray *)args {

#define args_length_judgments(_index_) \
    [self argsLengthJudgment:args index:_index_] \

#define set_with_args(_index_, _type_, _sel_) \
do { \
    _type_ arg; \
    if (args_length_judgments(_index_-2)) { \
        arg = [args[_index_-2] _sel_]; \
    } \
    [inv setArgument:&arg atIndex:_index_]; \
} while(0)

#define set_with_args_struct(_dic_, _struct_, _param_, _key_, _sel_) \
do { \
    if (_dic_ && [_dic_ isKindOfClass:[NSDictionary class]]) { \
        if ([_dic_.allKeys containsObject:_key_]) { \
            _struct_._param_ = [_dic_[_key_] _sel_]; \
        } \
    } \
} while(0)

    NSUInteger count = [sign numberOfArguments];
    for (int index = 2; index < count; index++) {
        char *type = (char *)[sign getArgumentTypeAtIndex:index];
        while (*type == 'r' ||  // const
               *type == 'n' ||  // in
               *type == 'N' ||  // inout
               *type == 'o' ||  // out
               *type == 'O' ||  // bycopy
               *type == 'R' ||  // byref
               *type == 'V') {  // oneway
            type++;             // cutoff useless prefix
        }

        BOOL unsupportedType = NO;
        switch (*type) {
            case 'v':   // 1:void
            case 'B':   // 1:bool
            case 'c':   // 1: char / BOOL
            case 'C':   // 1: unsigned char
            case 's':   // 2: short
            case 'S':   // 2: unsigned short
            case 'i':   // 4: int / NSInteger(32bit)
            case 'I':   // 4: unsigned int / NSUInteger(32bit)
            case 'l':   // 4: long(32bit)
            case 'L':   // 4: unsigned long(32bit)
            { // 'char' and 'short' will be promoted to 'int'
                set_with_args(index, int, intValue);
            } break;

            case 'q':   // 8: long long / long(64bit) / NSInteger(64bit)
            case 'Q':   // 8: unsigned long long / unsigned long(64bit) / NSUInteger(64bit)
            {
                set_with_args(index, long long, longLongValue);
            } break;

            case 'f': // 4: float / CGFloat(32bit)
            {
                set_with_args(index, float, floatValue);
            } break;

            case 'd': // 8: double / CGFloat(64bit)
            case 'D': // 16: long double
            {
                set_with_args(index, double, doubleValue);
            } break;

            case '*': // char *
            {
                if (args_length_judgments(index-2)) {
                    NSString *arg = args[index-2];
                    if ([arg isKindOfClass:[NSString class]]) {
                        const void *c = [arg UTF8String];
                        [inv setArgument:&c atIndex:index];
                    }
                }
            } break;

            case '#': // Class
            {
                if (args_length_judgments(index-2)) {
                    NSString *arg = args[index-2];
                    if ([arg isKindOfClass:[NSString class]]) {
                        Class klass = NSClassFromString(arg);
                        if (klass) {
                            [inv setArgument:&klass atIndex:index];
                        }
                    }
                }
            } break;

            case '@': // id
            {
                if (args_length_judgments(index-2)) {
                    id arg = args[index-2];
                    [inv setArgument:&arg atIndex:index];
                }
            } break;

            case '{': // struct
            {
                if (strcmp(type, @encode(CGPoint)) == 0) {
                    CGPoint point = {0};

                    if (args_length_judgments(index-2)) {
                        NSDictionary *dict = args[index-2];
                        set_with_args_struct(dict, point, x, @"x", doubleValue);
                        set_with_args_struct(dict, point, y, @"y", doubleValue);
                    }
                    [inv setArgument:&point atIndex:index];
                } else if (strcmp(type, @encode(CGSize)) == 0) {
                    CGSize size = {0};

                    if (args_length_judgments(index-2)) {
                        NSDictionary *dict = args[index-2];
                        set_with_args_struct(dict, size, width, @"width", doubleValue);
                        set_with_args_struct(dict, size, height, @"height", doubleValue);
                    }
                    [inv setArgument:&size atIndex:index];
                } else if (strcmp(type, @encode(CGRect)) == 0) {
                    CGRect rect;
                    CGPoint origin = {0};
                    CGSize size = {0};

                    if (args_length_judgments(index-2)) {
                        NSDictionary *dict = args[index-2];
                        NSDictionary *pDict = dict[@"origin"];
                        set_with_args_struct(pDict, origin, x, @"x", doubleValue);
                        set_with_args_struct(pDict, origin, y, @"y", doubleValue);

                        NSDictionary *sDict = dict[@"size"];
                        set_with_args_struct(sDict, size, width, @"width", doubleValue);
                        set_with_args_struct(sDict, size, height, @"height", doubleValue);
                    }
                    rect.origin = origin;
                    rect.size = size;
                    [inv setArgument:&rect atIndex:index];
                } else if (strcmp(type, @encode(CGVector)) == 0) {
                    CGVector vector = {0};

                    if (args_length_judgments(index-2)) {
                        NSDictionary *dict = args[index-2];
                        set_with_args_struct(dict, vector, dx, @"dx", doubleValue);
                        set_with_args_struct(dict, vector, dy, @"dy", doubleValue);
                    }
                    [inv setArgument:&vector atIndex:index];
                } else if (strcmp(type, @encode(CGAffineTransform)) == 0) {
                    CGAffineTransform form = {0};

                    if (args_length_judgments(index-2)) {
                        NSDictionary *dict = args[index-2];
                        set_with_args_struct(dict, form, a, @"a", doubleValue);
                        set_with_args_struct(dict, form, b, @"b", doubleValue);
                        set_with_args_struct(dict, form, c, @"c", doubleValue);
                        set_with_args_struct(dict, form, d, @"d", doubleValue);
                        set_with_args_struct(dict, form, tx, @"tx", doubleValue);
                        set_with_args_struct(dict, form, ty, @"ty", doubleValue);
                    }
                    [inv setArgument:&form atIndex:index];
                } else if (strcmp(type, @encode(CATransform3D)) == 0) {
                    CATransform3D form3D = {0};

                    if (args_length_judgments(index-2)) {
                        NSDictionary *dict = args[index-2];
                        set_with_args_struct(dict, form3D, m11, @"m11", doubleValue);
                        set_with_args_struct(dict, form3D, m12, @"m12", doubleValue);
                        set_with_args_struct(dict, form3D, m13, @"m13", doubleValue);
                        set_with_args_struct(dict, form3D, m14, @"m14", doubleValue);
                        set_with_args_struct(dict, form3D, m21, @"m21", doubleValue);
                        set_with_args_struct(dict, form3D, m22, @"m22", doubleValue);
                        set_with_args_struct(dict, form3D, m23, @"m23", doubleValue);
                        set_with_args_struct(dict, form3D, m24, @"m24", doubleValue);
                        set_with_args_struct(dict, form3D, m31, @"m31", doubleValue);
                        set_with_args_struct(dict, form3D, m32, @"m32", doubleValue);
                        set_with_args_struct(dict, form3D, m33, @"m33", doubleValue);
                        set_with_args_struct(dict, form3D, m34, @"m34", doubleValue);
                        set_with_args_struct(dict, form3D, m41, @"m41", doubleValue);
                        set_with_args_struct(dict, form3D, m42, @"m42", doubleValue);
                        set_with_args_struct(dict, form3D, m43, @"m43", doubleValue);
                        set_with_args_struct(dict, form3D, m44, @"m44", doubleValue);
                    }
                    [inv setArgument:&form3D atIndex:index];
                } else if (strcmp(type, @encode(NSRange)) == 0) {
                    NSRange range = {0};

                    if (args_length_judgments(index-2)) {
                        NSDictionary *dict = args[index-2];
                        set_with_args_struct(dict, range, location, @"location", unsignedIntegerValue);
                        set_with_args_struct(dict, range, length, @"length", unsignedIntegerValue);
                    }
                    [inv setArgument:&range atIndex:index];
                } else if (strcmp(type, @encode(UIOffset)) == 0) {
                    UIOffset offset = {0};

                    if (args_length_judgments(index-2)) {
                        NSDictionary *dict = args[index-2];
                        set_with_args_struct(dict, offset, horizontal, @"horizontal", doubleValue);
                        set_with_args_struct(dict, offset, vertical, @"vertical", doubleValue);
                    }
                    [inv setArgument:&offset atIndex:index];
                } else if (strcmp(type, @encode(UIEdgeInsets)) == 0) {
                    UIEdgeInsets insets = {0};

                    if (args_length_judgments(index-2)) {
                        NSDictionary *dict = args[index-2];
                        set_with_args_struct(dict, insets, top, @"top", doubleValue);
                        set_with_args_struct(dict, insets, left, @"left", doubleValue);
                        set_with_args_struct(dict, insets, bottom, @"bottom", doubleValue);
                        set_with_args_struct(dict, insets, right, @"right", doubleValue);
                    }
                    [inv setArgument:&insets atIndex:index];
                } else {
                    unsupportedType = YES;
                }
            } break;

            case '^': // pointer
            {
                unsupportedType = YES;
            } break;

            case ':': // SEL
            {
                unsupportedType = YES;
            } break;

            case '(': // union
            {
                unsupportedType = YES;
            } break;

            case '[': // array
            {
                unsupportedType = YES;
            } break;

            default: // what?!
            {
                unsupportedType = YES;
            } break;
        }

        NSAssert(!unsupportedType, @"arg unsupportedType");
    }
}

+ (BOOL)argsLengthJudgment:(NSArray *)args index:(NSInteger)index {
    return [args isKindOfClass:[NSArray class]] && index < args.count;
}

@end
