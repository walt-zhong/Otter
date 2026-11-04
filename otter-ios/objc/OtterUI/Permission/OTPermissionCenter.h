#import <UIKit/UIKit.h>
#import "../OTCore.h"

NS_ASSUME_NONNULL_BEGIN

@interface OTPermissionCenter : NSObject

+ (OTPermissionCenter *)installWithHost:(UIViewController *)host prompts:(nullable NSDictionary<NSString *, PermissionPrompt *> *)prompts;
+ (nullable OTPermissionCenter *)find:(UIView *)view;
- (void)releaseCenter;
- (void)publishAll:(UIView *)view;
- (PermissionResult *)check:(NSString *)capability;

@end

NS_ASSUME_NONNULL_END
