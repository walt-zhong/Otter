#import <UIKit/UIKit.h>
#import "../OTCore.h"

@class OTTemplateContext;

NS_ASSUME_NONNULL_BEGIN

@interface OTEvents : NSObject
+ (void)attachClick:(UIView *)view names:(NSArray<NSString *> *)names;
+ (void)fireChange:(UIView *)view;
+ (void)dispatchView:(UIView *)view event:(nullable JSONObject *)event itemData:(nullable JSONObject *)itemData template:(OTTemplateContext *)template;
+ (nullable UIView *)resolve:(UIView *)view template:(OTTemplateContext *)template idName:(nullable NSString *)idName;
@end

NS_ASSUME_NONNULL_END
