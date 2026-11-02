#import "PermissionResult.h"
#import "PermissionCapability.h"

@implementation PermissionResult

- (instancetype)initWithCapability:(NSString *)capability
                            status:(NSString *)status
                       canAskAgain:(BOOL)canAskAgain
                             asked:(BOOL)asked
                            detail:(NSString *)detail {
    self = [super init];
    if (self != nil) {
        _capability = [capability copy];
        _status = [status copy];
        _canAskAgain = canAskAgain;
        _asked = asked;
        _detail = detail == nil ? @"" : [detail copy];
    }
    return self;
}

- (BOOL)showSettings {
    return [self.status isEqualToString:[PermissionStatus PERMANENTLY_DENIED]] ||
        ([self.status isEqualToString:[PermissionStatus LIMITED]] && !self.canAskAgain);
}

- (NSString *)statusText {
    if ([self.capability isEqualToString:[PermissionCapability PHOTOS]]) {
        if ([self.status isEqualToString:[PermissionStatus GRANTED]]) {
            return @"已选好一张";
        }
        if ([self.status isEqualToString:[PermissionStatus UNSUPPORTED]]) {
            return @"当前版本没有这项";
        }
        if ([self.status isEqualToString:[PermissionStatus RESTRICTED]]) {
            return @"被系统限制";
        }
        return self.asked ? @"没有选图片" : @"还没选过";
    }
    if ([self.capability isEqualToString:[PermissionCapability LOCATION_WHEN_IN_USE]]) {
        if ([self.status isEqualToString:[PermissionStatus GRANTED]]) {
            return @"已允许，精确位置";
        }
        if ([self.status isEqualToString:[PermissionStatus LIMITED]]) {
            return @"只给了大致位置";
        }
        if ([self.status isEqualToString:[PermissionStatus PERMANENTLY_DENIED]]) {
            return @"已关闭，要到系统设置里打开";
        }
        if ([self.status isEqualToString:[PermissionStatus RESTRICTED]]) {
            return @"被系统限制";
        }
        if ([self.status isEqualToString:[PermissionStatus UNSUPPORTED]]) {
            return @"当前版本没有这项";
        }
        return self.asked ? @"未允许" : @"还没问过";
    }
    if ([self.status isEqualToString:[PermissionStatus GRANTED]]) {
        return @"已允许";
    }
    if ([self.status isEqualToString:[PermissionStatus LIMITED]]) {
        return @"只给了一部分";
    }
    if ([self.status isEqualToString:[PermissionStatus PERMANENTLY_DENIED]]) {
        return @"已关闭，要到系统设置里打开";
    }
    if ([self.status isEqualToString:[PermissionStatus RESTRICTED]]) {
        return @"被系统限制";
    }
    if ([self.status isEqualToString:[PermissionStatus UNSUPPORTED]]) {
        return @"当前版本没有这项";
    }
    return self.asked ? @"未允许" : @"还没问过";
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[PermissionResult class]]) {
        return NO;
    }
    PermissionResult *other = object;
    return [self.capability isEqualToString:other.capability] &&
        [self.status isEqualToString:other.status] &&
        self.canAskAgain == other.canAskAgain &&
        self.asked == other.asked &&
        [self.detail isEqualToString:other.detail];
}

- (NSUInteger)hash {
    return self.capability.hash ^ self.status.hash ^ self.detail.hash;
}

@end

@implementation PermissionPrompt

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message {
    self = [super init];
    if (self != nil) {
        _title = [title copy];
        _message = [message copy];
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[PermissionPrompt class]]) {
        return NO;
    }
    PermissionPrompt *other = object;
    return [self.title isEqualToString:other.title] && [self.message isEqualToString:other.message];
}

- (NSUInteger)hash {
    return self.title.hash ^ self.message.hash;
}

@end
