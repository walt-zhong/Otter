#import "ExpansionCenter.h"
#import "../OTCore.h"

@implementation ExpansionCenter {
    NSMutableDictionary<NSString *, void (^)(UIView *, JSONObject *)> *_hostActions;
}

+ (ExpansionCenter *)shared {
    static ExpansionCenter *center;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        center = [ExpansionCenter new];
    });
    return center;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _hostActions = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)registerPageOpener:(void (^)(UIViewController *, NSString *))opener {
    self.pageOpener = opener;
}

+ (BOOL)hostNameIsIdentifier:(NSString *)name {
    if (name.length == 0) {
        return NO;
    }
    unichar first = [name characterAtIndex:0];
    if (!((first >= 'A' && first <= 'Z') || (first >= 'a' && first <= 'z') || first == '_')) {
        return NO;
    }
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_"];
    return [name rangeOfCharacterFromSet:allowed.invertedSet].location == NSNotFound;
}

- (void)registerHostAction:(NSString *)name action:(void (^)(UIView *, JSONObject *))action {
    if (![ExpansionCenter hostNameIsIdentifier:name] || !action) {
        return;
    }
    _hostActions[name] = [action copy];
}

- (void)unregisterHostAction:(NSString *)name {
    [_hostActions removeObjectForKey:name];
}

- (BOOL)dispatchHost:(UIView *)view name:(NSString *)name params:(JSONObject *)params {
    if (![ExpansionCenter hostNameIsIdentifier:name]) {
        return NO;
    }
    void (^action)(UIView *, JSONObject *) = _hostActions[name];
    if (!action) {
        return NO;
    }
    action(view, params);
    return YES;
}

@end
