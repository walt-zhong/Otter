#import "ExpressionEngine.h"
#import "../../ThirdParty/OtterAnalyzeBridge/include/OTExpressionBridge.h"

#include <string.h>

@implementation ExpressionEngine {
    OTExpressionBridge *_bridge;
}

+ (ExpressionEngine *)shared {
    static ExpressionEngine *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[ExpressionEngine alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _bridge = [[OTExpressionBridge alloc] init];
    }
    return self;
}

- (id)resultWithExpression:(id)expression data:(id)data {
    id evaluated = [self evaluate:expression data:data];
    if ([expression isKindOfClass:[NSString class]] && evaluated == nil) {
        return expression;
    }
    return evaluated;
}

- (id)evaluate:(id)expression data:(id)data {
    if ([expression isKindOfClass:[NSString class]]) {
        NSString *text = expression;
        NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([trimmed isEqualToString:@"$$"]) {
            return data;
        }
        if (trimmed.length == 0) {
            return nil;
        }
        return [self unwrap:[_bridge evaluateString:text data:data]];
    }
    if ([expression isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = expression;
        NSMutableDictionary *object = [NSMutableDictionary dictionaryWithCapacity:dictionary.count];
        for (id key in dictionary) {
            if (![key isKindOfClass:[NSString class]]) {
                continue;
            }
            id value = dictionary[key];
            id evaluated = [self evaluate:value data:data];
            object[key] = evaluated ?: [NSNull null];
        }
        return [object copy];
    }
    if ([expression isKindOfClass:[NSArray class]]) {
        NSArray *list = expression;
        NSMutableArray *object = [NSMutableArray arrayWithCapacity:list.count];
        for (id value in list) {
            id evaluated = [self evaluate:value data:data];
            [object addObject:evaluated ?: [NSNull null]];
        }
        return [object copy];
    }
    if ([expression isKindOfClass:[NSNumber class]]) {
        return [self passthroughNumber:expression];
    }
    return nil;
}

- (id)passthroughNumber:(NSNumber *)number {
    if (CFGetTypeID((__bridge CFTypeRef)number) == CFBooleanGetTypeID()) {
        return [NSNumber numberWithBool:number.boolValue];
    }
    const char *encoding = number.objCType;
    if (strcmp(encoding, "f") == 0) {
        return [NSNumber numberWithFloat:number.floatValue];
    }
    if (strcmp(encoding, "i") == 0) {
        return [NSNumber numberWithInt:number.intValue];
    }
    if (strcmp(encoding, "q") == 0 || strcmp(encoding, "l") == 0) {
        return [NSNumber numberWithLongLong:number.longLongValue];
    }
    return nil;
}

- (id)unwrap:(OTEvalBox *)box {
    if (box == nil) {
        return nil;
    }
    switch (box.kind) {
        case OTEvalKindBool:
            return [NSNumber numberWithBool:box.boolValue];
        case OTEvalKindLong:
            return [NSNumber numberWithLongLong:box.longValue];
        case OTEvalKindFloat:
            return [NSNumber numberWithFloat:box.floatValue];
        case OTEvalKindString:
            if ([box.objectValue isKindOfClass:[NSString class]]) {
                return box.objectValue;
            }
            return @"";
        case OTEvalKindArray:
        case OTEvalKindMap:
            return box.objectValue;
        default:
            return nil;
    }
}

@end
