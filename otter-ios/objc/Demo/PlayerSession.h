#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PlayerSession : NSObject
+ (nullable instancetype)attach:(UIView *)root;
- (void)releaseSession;
@end

NS_ASSUME_NONNULL_END
