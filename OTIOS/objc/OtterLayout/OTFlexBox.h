#import "OTSize.h"
#import "OTStretchStyle.h"

NS_ASSUME_NONNULL_BEGIN

@interface OTEdgeSizes : NSObject
@property (nonatomic, strong) OTSize *start;
@property (nonatomic, strong) OTSize *end;
@property (nonatomic, strong) OTSize *top;
@property (nonatomic, strong) OTSize *bottom;
@end

BOOL OTEdgeSizesCreate(NSString *_Nullable uniform,
                       NSString *_Nullable start,
                       NSString *_Nullable end,
                       NSString *_Nullable top,
                       NSString *_Nullable bottom,
                       float windowWidthPoints,
                       OTEdgeSizes *_Nullable *_Nonnull outEdges,
                       NSError **error);

BOOL OTSameStretchDimension(StretchStyleDimension current, StretchStyleDimension next);

@interface OTFlexBox : NSObject
@property (nonatomic, assign) OTFlexDisplay display;
@property (nonatomic, assign) BOOL hasFlexDirection;
@property (nonatomic, assign) OTFlexMainAxis flexDirection;
@property (nonatomic, assign) BOOL hasAlignItems;
@property (nonatomic, assign) OTFlexAlign alignItems;
@property (nonatomic, assign) BOOL hasJustifyContent;
@property (nonatomic, assign) OTFlexJustify justifyContent;
@property (nonatomic, strong, nullable) OTEdgeSizes *padding;
@property (nonatomic, strong, nullable) OTEdgeSizes *margin;
@property (nonatomic, strong) OTSize *width;
@property (nonatomic, strong) OTSize *height;
@property (nonatomic, assign) BOOL hasMinSize;
@property (nonatomic, strong, nullable) OTSize *minWidth;
@property (nonatomic, strong, nullable) OTSize *minHeight;
@property (nonatomic, assign) BOOL hasMaxSize;
@property (nonatomic, strong, nullable) OTSize *maxWidth;
@property (nonatomic, strong, nullable) OTSize *maxHeight;
@property (nonatomic, assign) float flexGrow;
@property (nonatomic, assign) BOOL hasAspectRatio;
@property (nonatomic, assign) float aspectRatio;
@property (nonatomic, assign) BOOL hasFlexWrap;
@property (nonatomic, assign) OTFlexWrapMode flexWrap;
@property (nonatomic, assign) BOOL hasAlignSelf;
@property (nonatomic, assign) OTFlexAlignSelf alignSelf;

+ (nullable OTFlexBox *)flexBoxWithViewName:(NSString *)viewName
                                     fields:(NSDictionary<NSString *, NSString *> *)fields
                         windowWidthPoints:(float)windowWidthPoints
                                      error:(NSError **)error;
- (OTStretchStyle *)makeStyle;
@end

NS_ASSUME_NONNULL_END
