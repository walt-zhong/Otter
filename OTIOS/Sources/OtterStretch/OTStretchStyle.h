#import "OTStretch.h"

NS_ASSUME_NONNULL_BEGIN

/// Owns one `stretch_style_create` pointer. Defaults match StretchKit `Style.init`,
/// except `flexShrink` stays available for Otter to pass Android's 0.
@interface OTStretchStyle : NSObject
@property (nonatomic, readonly) void *rustptr;
- (instancetype)initWithDisplay:(OTFlexDisplay)display
                   positionType:(OTFlexPositionType)positionType
                      direction:(OTFlexDirectionAxis)direction
                  flexDirection:(OTFlexMainAxis)flexDirection
                       flexWrap:(OTFlexWrapMode)flexWrap
                       overflow:(OTFlexOverflow)overflow
                     alignItems:(OTFlexAlign)alignItems
                      alignSelf:(OTFlexAlignSelf)alignSelf
                   alignContent:(OTFlexAlignContent)alignContent
                 justifyContent:(OTFlexJustify)justifyContent
                       position:(StretchStyleRect)position
                         margin:(StretchStyleRect)margin
                        padding:(StretchStyleRect)padding
                         border:(StretchStyleRect)border
                       flexGrow:(float)flexGrow
                     flexShrink:(float)flexShrink
                      flexBasis:(StretchStyleDimension)flexBasis
                           size:(StretchStyleSize)size
                        minSize:(StretchStyleSize)minSize
                        maxSize:(StretchStyleSize)maxSize
                    aspectRatio:(float)aspectRatio;
@end

NS_ASSUME_NONNULL_END
