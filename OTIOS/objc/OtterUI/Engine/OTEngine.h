#import <UIKit/UIKit.h>

@class JSONObject;
@class ParsedTemplate;
@class OTLaidOutNode;

NS_ASSUME_NONNULL_BEGIN

@interface OTTemplateContext : NSObject

@property (nonatomic, copy, readonly) NSString *bizId;
@property (nonatomic, copy, readonly) NSString *templateId;
@property (nonatomic, copy, readonly) NSString *templatePath;
@property (nonatomic, strong, nullable) JSONObject *data;
@property (nonatomic, copy) NSDictionary<NSString *, JSONObject *> *events;
@property (nonatomic, strong, nullable) ParsedTemplate *parsed;
@property (nonatomic, weak, nullable) UIView *rootView;
@property (nonatomic, assign) CGSize viewport;
@property (nonatomic, assign) CGFloat scale;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIView *> *viewIds;
@property (nonatomic, strong, nullable) OTLaidOutNode *laidOut;

- (void)releaseTemplate;

@end

@interface OTEngine : NSObject

@property (class, nonatomic, readonly) OTEngine *shared;

- (OTTemplateContext *)buildTemplateWithBizId:(NSString *)bizId
                                   templateId:(NSString *)templateId
                                 templatePath:(NSString *)templatePath;
- (BOOL)setData:(NSString *)json forTemplate:(OTTemplateContext *)template error:(NSError **)error;
- (nullable UIView *)createViewForTemplate:(OTTemplateContext *)template
                                  viewport:(CGSize)viewport
                                     error:(NSError **)error;
- (void)relayoutTemplate:(OTTemplateContext *)template viewport:(CGSize)viewport;
- (BOOL)rebindTemplate:(OTTemplateContext *)template error:(NSError **)error;
- (void)releaseTemplate:(OTTemplateContext *)template;

@end

NS_ASSUME_NONNULL_END
