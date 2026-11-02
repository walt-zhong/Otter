#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface StackController : UIViewController
@property (nonatomic, copy, readonly) NSString *route;
@property (nonatomic, copy, readonly) NSString *bizId;
@property (nonatomic, copy, readonly) NSString *templateId;
@property (nonatomic, copy) NSString *chromeTitle;
- (instancetype)initWithRoute:(NSString *)route bizId:(NSString *)bizId templateId:(NSString *)templateId;
@end

NS_ASSUME_NONNULL_END
