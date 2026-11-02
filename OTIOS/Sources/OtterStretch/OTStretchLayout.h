#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Float layout tree. Parsing matches StretchKit `Layout.fromFloats`, which walks
/// the buffer forward. GaiaX `GXLayout` restarts at `ptr + 5` on every child.
@interface OTStretchLayout : NSObject
@property (nonatomic, readonly) float x;
@property (nonatomic, readonly) float y;
@property (nonatomic, readonly) float width;
@property (nonatomic, readonly) float height;
@property (nonatomic, readonly) NSArray<OTStretchLayout *> *children;
+ (instancetype)fromFloats:(const float *)floats consumed:(const float *_Nullable *_Nonnull)consumed;
@end

NS_ASSUME_NONNULL_END
