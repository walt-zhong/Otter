#import <UIKit/UIKit.h>

@class JSONObject;

NS_ASSUME_NONNULL_BEGIN

@interface OTVectorImage : NSObject
+ (nullable UIImage *)imageAtURL:(NSURL *)url;
@end

@interface OTChrome : NSObject
+ (CGFloat)scaleForView:(UIView *)view;
+ (void)applyView:(UIView *)view
           fields:(NSDictionary<NSString *, NSString *> *)fields
            scale:(CGFloat)scale
         itemData:(nullable JSONObject *)itemData;
+ (nullable NSString *)eval:(nullable NSString *)raw data:(nullable JSONObject *)data;
+ (UIBezierPath *)cornerPath:(CGRect)rect radii:(NSArray<NSNumber *> *)radii;
@end

@interface OTGlassLayer : NSObject
+ (void)attach:(UIView *)view fields:(NSDictionary<NSString *, NSString *> *)fields itemData:(nullable JSONObject *)itemData;
+ (void)remove:(UIView *)view;
+ (void)layout:(UIView *)view;
@end

NS_ASSUME_NONNULL_END
