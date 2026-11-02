#import "PageFrames.h"

@implementation PageFrames {
    NSMutableArray<NSString *> *_names;
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _names = [NSMutableArray array];
    }
    return self;
}

- (NSInteger)depth {
    return (NSInteger)_names.count;
}

- (void)push:(NSString *)name {
    [_names addObject:name];
}

- (NSString *)pop {
    if (self.depth <= 1) {
        return nil;
    }
    NSString *name = _names.lastObject;
    [_names removeLastObject];
    return name;
}

- (NSString *)drop {
    if (_names.count == 0) {
        return nil;
    }
    NSString *name = _names.lastObject;
    [_names removeLastObject];
    return name;
}

- (NSArray<NSString *> *)popTo:(NSString *)name {
    NSInteger index = NSNotFound;
    for (NSInteger cursor = (NSInteger)_names.count - 1; cursor >= 0; cursor--) {
        if ([_names[(NSUInteger)cursor] isEqualToString:name]) {
            index = cursor;
            break;
        }
    }
    if (index == NSNotFound) {
        return nil;
    }
    NSMutableArray<NSString *> *removed = [NSMutableArray array];
    while ((NSInteger)_names.count - 1 > index) {
        [removed addObject:_names.lastObject];
        [_names removeLastObject];
    }
    return removed;
}

- (NSString *)top {
    return _names.lastObject;
}

- (NSArray<NSString *> *)clear {
    NSArray<NSString *> *remaining = [_names copy];
    [_names removeAllObjects];
    return remaining;
}

@end
