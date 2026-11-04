#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ScreenAdapt : NSObject
@property (class, nonatomic, readonly) CGFloat DESIGN_WIDTH_DP;
+ (CGFloat)scaleForWindowWidth:(CGFloat)windowWidth;
+ (CGFloat)scaleForWindowWidth:(CGFloat)windowWidth designWidth:(CGFloat)designWidth;
@end

NS_ASSUME_NONNULL_END
