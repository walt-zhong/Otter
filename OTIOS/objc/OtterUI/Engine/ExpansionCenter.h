#import <UIKit/UIKit.h>

@class JSONObject;

NS_ASSUME_NONNULL_BEGIN

@interface ExpansionCenter : NSObject

@property (class, nonatomic, readonly) ExpansionCenter *shared;
@property (nonatomic, copy, nullable) void (^pageOpener)(UIViewController *controller, NSString *page);
@property (nonatomic, copy, nullable) void (^itemClick)(NSDictionary<NSString *, NSString *> *item);

- (void)registerPageOpener:(void (^)(UIViewController *controller, NSString *page))opener;
- (void)registerHostAction:(NSString *)name action:(void (^)(UIView *view, JSONObject *_Nullable params))action;
- (BOOL)dispatchHost:(UIView *)view name:(NSString *)name params:(nullable JSONObject *)params;

@end

NS_ASSUME_NONNULL_END
