#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TemplateScreen : NSObject

- (instancetype)initWithController:(UIViewController *)controller
                         container:(UIView *)container
                      templatePath:(NSString *)templatePath
                          dataPath:(nullable NSString *)dataPath
                           onReady:(void (^ _Nullable)(UIView *root))onReady;
- (void)noteSafeArea;
- (void)noteLayout;
- (void)noteAppear;

@end

NS_ASSUME_NONNULL_END
