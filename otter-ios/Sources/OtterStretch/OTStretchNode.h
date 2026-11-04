#import "OTStretchStyle.h"
#import "OTStretchLayout.h"

NS_ASSUME_NONNULL_BEGIN

typedef StretchSize (^OTStretchMeasure)(float width, float height);

/// Node tree. `computeLayoutWidth:height:` treats NAN as an undefined constraint,
/// the same as StretchKit `Size<Float?>` nil. A width or height of 0 stays 0.
@interface OTStretchNode : NSObject
@property (nonatomic, strong) OTStretchStyle *style;
@property (nonatomic, copy, readonly) NSArray<OTStretchNode *> *children;
- (instancetype)initWithStyle:(OTStretchStyle *)style children:(NSArray<OTStretchNode *> *)children;
- (instancetype)initWithStyle:(OTStretchStyle *)style measure:(OTStretchMeasure)measure;
- (void)addChild:(OTStretchNode *)child;
- (void)markDirty;
- (OTStretchLayout *)computeLayoutWidth:(float)width height:(float)height;
@end

NS_ASSUME_NONNULL_END
