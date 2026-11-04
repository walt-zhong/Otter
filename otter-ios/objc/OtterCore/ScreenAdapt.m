#import "ScreenAdapt.h"

@implementation ScreenAdapt

+ (CGFloat)DESIGN_WIDTH_DP {
    return 375;
}

+ (CGFloat)scaleForWindowWidth:(CGFloat)windowWidth {
    return [self scaleForWindowWidth:windowWidth designWidth:[self DESIGN_WIDTH_DP]];
}

+ (CGFloat)scaleForWindowWidth:(CGFloat)windowWidth designWidth:(CGFloat)designWidth {
    if (windowWidth <= 0 || designWidth <= 0) {
        return 1;
    }
    CGFloat basis = windowWidth < 480 ? windowWidth : 480;
    CGFloat ratio = basis / designWidth;
    return ratio > 0.88 ? ratio : 0.88;
}

@end
