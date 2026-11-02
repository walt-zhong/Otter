#import <UIKit/UIKit.h>
#import "../OTCore.h"

NS_ASSUME_NONNULL_BEGIN

@interface PageStack : NSObject <UIGestureRecognizerDelegate>

@property (class, nonatomic, readonly) NSInteger maxStateCharacters;
@property (nonatomic, assign, readonly) NSInteger depth;
@property (nonatomic, copy, nullable) void (^onInsets)(void);

+ (nullable PageStack *)attachWithHost:(UIViewController *)host
                             insetRoot:(UIView *)insetRoot
                             container:(UIView *)container
                             routePath:(NSString *)routePath
                                 bizId:(NSString *)bizId
                            templateId:(NSString *)templateId
                                 error:(NSError **)error;
+ (nullable PageStack *)find:(UIView *)view;
- (void)activate;
- (void)releaseStack;
- (void)layoutContainers;
- (void)open:(NSString *)page raw:(nullable JSONObject *)raw item:(nullable JSONObject *)item pageData:(nullable JSONObject *)pageData;
- (void)replace:(NSString *)page raw:(nullable JSONObject *)raw item:(nullable JSONObject *)item pageData:(nullable JSONObject *)pageData;
- (BOOL)pop:(nullable JSONObject *)raw;
- (BOOL)popTo:(NSString *)page raw:(nullable JSONObject *)raw;
- (void)editCurrentData:(void (^)(JSONObject *data))block;
- (void)rebindCurrent;
- (nullable NSString *)exportState;
- (void)restoreState:(nullable NSString *)text;

@end

NS_ASSUME_NONNULL_END
