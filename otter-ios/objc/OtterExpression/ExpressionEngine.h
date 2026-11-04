#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// String results come from OTExpressionBridge. A string expression whose
/// evaluation is nil is replaced with the original string. Nested values
/// inside a map or array do not get that replacement.
@interface ExpressionEngine : NSObject
@property (class, nonatomic, readonly) ExpressionEngine *shared;
- (nullable id)resultWithExpression:(id)expression data:(nullable id)data;
@end

NS_ASSUME_NONNULL_END
