#import <Foundation/Foundation.h>
#import "PermissionResult.h"

NS_ASSUME_NONNULL_BEGIN

@interface PermissionPrompts : NSObject
+ (NSDictionary<NSString *, PermissionPrompt *> *)standard;
@end

NS_ASSUME_NONNULL_END
