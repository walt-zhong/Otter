#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// `ViewAttr.applyCommon` keeps these raw. Container justify, align, and
/// flexWrap are stored without `extractExpValue`. `scroll` is compared to
/// "true" on the raw string.
@interface OTUnevaluatedKeys : NSObject
+ (BOOL)containsName:(NSString *)name;
@end

NS_ASSUME_NONNULL_END
