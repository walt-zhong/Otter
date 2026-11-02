#import "OTStretch.h"

NS_ASSUME_NONNULL_BEGIN

/// `OTSize.valueInt` truncates points and the 0...1 percent fraction toward zero.
@interface OTSize : NSObject
@property (nonatomic, readonly) float value;
+ (OTSize *)sizeWithPoints:(float)value;
+ (OTSize *)sizeWithPercent:(float)value;
+ (OTSize *)autoSize;
+ (OTSize *)undefinedSize;
+ (nullable OTSize *)sizeWithString:(NSString *)raw
                 windowWidthPoints:(float)windowWidthPoints
                             error:(NSError **)error;
- (StretchStyleDimension)dimension;
- (int64_t)valueInt;
- (float)valueFloat;
@end

/// `Float.roundToInt` / `java.lang.Math.round`: floor(x + 0.5). Non-finite is 0.
FOUNDATION_EXPORT int64_t OTJavaRoundToInt(float value);
FOUNDATION_EXPORT int64_t OTTruncTowardZero(float value);

/// Swift `Float.init(String)`. The whole string must be a number.
FOUNDATION_EXPORT BOOL OTLayoutParseFloat(NSString *text, float *outValue);

NS_ASSUME_NONNULL_END
