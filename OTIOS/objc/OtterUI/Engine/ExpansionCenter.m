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

- (void)registerHostAction:(NSString *)name action:(void (^)(UIView *, JSONObject *))action {
    if (name.length == 0 || !action) {
        return;
    }
    _hostActions[name] = [action copy];
}

- (BOOL)dispatchHost:(UIView *)view name:(NSString *)name params:(JSONObject *)params {
    void (^action)(UIView *, JSONObject *) = _hostActions[name];
    if (!action) {
        return NO;
    }
    action(view, params);
    return YES;
}

@end
