#import <UIKit/UIKit.h>
#import "../OTCore.h"

@class OTTemplateContext;

NS_ASSUME_NONNULL_BEGIN

@interface OTViewTree : NSObject
+ (nullable UIView *)buildParsed:(ParsedNode *)parsed
                            laid:(OTLaidOutNode *)laid
                        template:(OTTemplateContext *)template
                        itemData:(nullable JSONObject *)itemData
                           error:(NSError **)error;
+ (BOOL)rebindView:(UIView *)view
            parsed:(ParsedNode *)parsed
              laid:(OTLaidOutNode *)laid
          template:(OTTemplateContext *)template
             error:(NSError **)error;
+ (void)applyFrames:(UIView *)view laid:(OTLaidOutNode *)laid;
@end

NS_ASSUME_NONNULL_END
