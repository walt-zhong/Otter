#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

UIColor *DemoPageColor(void);

@interface DemoTopBar : UIView
@property (nonatomic, copy, nullable) void (^onBack)(void);
+ (CGFloat)barHeight;
+ (instancetype)barWithTitle:(NSString *)title showsBack:(BOOL)showsBack;
@end

@interface DemoRoutes : NSObject
+ (void)open:(UIViewController *)controller page:(NSString *)page;
+ (void)goBack:(UIViewController *)controller;
+ (NSString *)titleForPage:(NSString *)page;
@end

NS_ASSUME_NONNULL_END
