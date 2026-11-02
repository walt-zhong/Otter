#import "OTStretchStyle.h"

@implementation OTStretchStyle

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
                    aspectRatio:(float)aspectRatio {
    self = [super init];
    if (self) {
        _rustptr = stretch_style_create((int32_t)display,
                                        (int32_t)positionType,
                                        (int32_t)direction,
                                        (int32_t)flexDirection,
                                        (int32_t)flexWrap,
                                        (int32_t)overflow,
                                        (int32_t)alignItems,
                                        (int32_t)alignSelf,
                                        (int32_t)alignContent,
                                        (int32_t)justifyContent,
                                        position,
                                        margin,
                                        padding,
                                        border,
                                        flexGrow,
                                        flexShrink,
                                        flexBasis,
                                        size,
                                        minSize,
                                        maxSize,
                                        aspectRatio);
    }
    return self;
}

- (void)dealloc {
    if (_rustptr) {
        stretch_style_free(_rustptr);
        _rustptr = NULL;
    }
}

@end
