//
//  OTStretch.h
//
//  Objective-C Stretch binding, matching GaiaXiOS GXStretch / GXStyle / GXLayout / GXNode.
//  The C API is the current GaiaX Stretch (start/end), not the older left/right header
//  checked into GaiaXiOS/Core/StretchKit/Headers/libstretch.h.
//

#import <Foundation/Foundation.h>
#import "libstretch.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(int32_t, OTFlexDisplay) {
    OTFlexDisplayFlex = 0,
    OTFlexDisplayNone = 1,
};

typedef NS_ENUM(int32_t, OTFlexPositionType) {
    OTFlexPositionRelative = 0,
    OTFlexPositionAbsolute = 1,
};

typedef NS_ENUM(int32_t, OTFlexDirectionAxis) {
    OTFlexDirectionInherit = 0,
    OTFlexDirectionLTR = 1,
    OTFlexDirectionRTL = 2,
};

typedef NS_ENUM(int32_t, OTFlexMainAxis) {
    OTFlexMainRow = 0,
    OTFlexMainColumn = 1,
    OTFlexMainRowReverse = 2,
    OTFlexMainColumnReverse = 3,
};

typedef NS_ENUM(int32_t, OTFlexWrapMode) {
    OTFlexWrapNone = 0,
    OTFlexWrapWrap = 1,
    OTFlexWrapReverse = 2,
};

typedef NS_ENUM(int32_t, OTFlexOverflow) {
    OTFlexOverflowVisible = 0,
    OTFlexOverflowHidden = 1,
    OTFlexOverflowScroll = 2,
};

typedef NS_ENUM(int32_t, OTFlexAlign) {
    OTFlexAlignStart = 0,
    OTFlexAlignEnd = 1,
    OTFlexAlignCenter = 2,
    OTFlexAlignBaseline = 3,
    OTFlexAlignStretch = 4,
};

typedef NS_ENUM(int32_t, OTFlexAlignSelf) {
    OTFlexAlignSelfAuto = 0,
    OTFlexAlignSelfStart = 1,
    OTFlexAlignSelfEnd = 2,
    OTFlexAlignSelfCenter = 3,
    OTFlexAlignSelfBaseline = 4,
    OTFlexAlignSelfStretch = 5,
};

typedef NS_ENUM(int32_t, OTFlexAlignContent) {
    OTFlexAlignContentStart = 0,
    OTFlexAlignContentEnd = 1,
    OTFlexAlignContentCenter = 2,
    OTFlexAlignContentStretch = 3,
    OTFlexAlignContentSpaceBetween = 4,
    OTFlexAlignContentSpaceAround = 5,
};

typedef NS_ENUM(int32_t, OTFlexJustify) {
    OTFlexJustifyStart = 0,
    OTFlexJustifyEnd = 1,
    OTFlexJustifyCenter = 2,
    OTFlexJustifySpaceBetween = 3,
    OTFlexJustifySpaceAround = 4,
    OTFlexJustifySpaceEvenly = 5,
};

static inline StretchStyleDimension OTDimenPoints(float value) {
    StretchStyleDimension dimen;
    dimen.dimen_type = 0;
    dimen.dimen_value = value;
    return dimen;
}

static inline StretchStyleDimension OTDimenPercent(float value) {
    StretchStyleDimension dimen;
    dimen.dimen_type = 1;
    dimen.dimen_value = value;
    return dimen;
}

static inline StretchStyleDimension OTDimenAuto(void) {
    StretchStyleDimension dimen;
    dimen.dimen_type = 2;
    dimen.dimen_value = 0;
    return dimen;
}

static inline StretchStyleDimension OTDimenUndefined(void) {
    StretchStyleDimension dimen;
    dimen.dimen_type = 3;
    dimen.dimen_value = 0;
    return dimen;
}

static inline StretchStyleSize OTStretchSize(StretchStyleDimension width, StretchStyleDimension height) {
    StretchStyleSize size;
    size.width = width;
    size.height = height;
    return size;
}

static inline StretchStyleRect OTStretchRect(StretchStyleDimension start,
                                             StretchStyleDimension end,
                                             StretchStyleDimension top,
                                             StretchStyleDimension bottom) {
    StretchStyleRect rect;
    rect.start = start;
    rect.end = end;
    rect.top = top;
    rect.bottom = bottom;
    return rect;
}

/// Same lock and C calls as GaiaX `GXStretch`.
@interface OTStretch : NSObject
+ (instancetype)shared;
- (void *)createNodeWithStyle:(void *)style;
- (void)freeNode:(void *)node;
- (void)setStyle:(void *)style forNode:(void *)node;
- (void)markDirty:(void *)node;
- (BOOL)isDirty:(void *)node;
- (void)addChild:(void *)child toNode:(void *)node;
- (void)removeChild:(void *)child fromNode:(void *)node;
- (void)removeChildAtIndex:(NSUInteger)index fromNode:(void *)node;
- (void)replaceChild:(void *)child atIndex:(NSUInteger)index forNode:(void *)node;
- (void)setMeasure:(StretchSize (^)(float width, float height))measure forNode:(void *)node context:(id)context;
- (nullable id)computeLayoutForNode:(void *)node width:(float)width height:(float)height;
@end

NS_ASSUME_NONNULL_END
