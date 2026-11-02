#import "OTFlexBox.h"

#import "TemplateKey.h"

#import <math.h>

@implementation OTEdgeSizes
@end

static StretchStyleDimension OTDimensionOrAuto(OTSize *size) {
    return size ? [size dimension] : OTDimenAuto();
}

static StretchStyleRect OTUndefinedRect(void) {
    StretchStyleDimension undefined = OTDimenUndefined();
    return OTStretchRect(undefined, undefined, undefined, undefined);
}

static StretchStyleRect OTEdgeRect(OTEdgeSizes *edges) {
    if (!edges) {
        return OTUndefinedRect();
    }
    return OTStretchRect([edges.start dimension],
                         [edges.end dimension],
                         [edges.top dimension],
                         [edges.bottom dimension]);
}

static BOOL OTResolveEdge(NSString *raw,
                          OTSize *fallback,
                          float windowWidthPoints,
                          OTSize **outSize,
                          NSError **error) {
    if (!raw) {
        *outSize = fallback;
        return YES;
    }
    OTSize *size = [OTSize sizeWithString:raw windowWidthPoints:windowWidthPoints error:error];
    if (!size) {
        return NO;
    }
    *outSize = size;
    return YES;
}

BOOL OTEdgeSizesCreate(NSString *uniform,
                       NSString *start,
                       NSString *end,
                       NSString *top,
                       NSString *bottom,
                       float windowWidthPoints,
                       OTEdgeSizes *_Nullable *_Nonnull outEdges,
                       NSError **error) {
    if (!uniform && !start && !end && !top && !bottom) {
        *outEdges = nil;
        return YES;
    }
    OTSize *fallback = nil;
    if (uniform) {
        fallback = [OTSize sizeWithString:uniform windowWidthPoints:windowWidthPoints error:error];
        if (!fallback) {
            return NO;
        }
    } else {
        fallback = [OTSize undefinedSize];
    }
    OTSize *startSize = nil;
    OTSize *endSize = nil;
    OTSize *topSize = nil;
    OTSize *bottomSize = nil;
    if (!OTResolveEdge(start, fallback, windowWidthPoints, &startSize, error) ||
        !OTResolveEdge(end, fallback, windowWidthPoints, &endSize, error) ||
        !OTResolveEdge(top, fallback, windowWidthPoints, &topSize, error) ||
        !OTResolveEdge(bottom, fallback, windowWidthPoints, &bottomSize, error)) {
        return NO;
    }
    OTEdgeSizes *edges = [[OTEdgeSizes alloc] init];
    edges.start = startSize;
    edges.end = endSize;
    edges.top = topSize;
    edges.bottom = bottomSize;
    *outEdges = edges;
    return YES;
}

BOOL OTSameStretchDimension(StretchStyleDimension current, StretchStyleDimension next) {
    if (current.dimen_type == 0 && next.dimen_type == 0) {
        return fabsf(current.dimen_value - next.dimen_value) < 1.0f;
    }
    if (current.dimen_type == 1 && next.dimen_type == 1) {
        return current.dimen_value == next.dimen_value;
    }
    if (current.dimen_type == 2 && next.dimen_type == 2) {
        return YES;
    }
    if (current.dimen_type == 3 && next.dimen_type == 3) {
        return YES;
    }
    return NO;
}

static BOOL OTParseJustify(NSString *target, OTFlexJustify *outValue) {
    if ([target isEqualToString:@"start"]) {
        *outValue = OTFlexJustifyStart;
        return YES;
    }
    if ([target isEqualToString:@"end"]) {
        *outValue = OTFlexJustifyEnd;
        return YES;
    }
    if ([target isEqualToString:@"center"]) {
        *outValue = OTFlexJustifyCenter;
        return YES;
    }
    if ([target isEqualToString:@"space-around"]) {
        *outValue = OTFlexJustifySpaceAround;
        return YES;
    }
    if ([target isEqualToString:@"space-between"]) {
        *outValue = OTFlexJustifySpaceBetween;
        return YES;
    }
    if ([target isEqualToString:@"space-evenly"]) {
        *outValue = OTFlexJustifySpaceEvenly;
        return YES;
    }
    return NO;
}

static BOOL OTParseAlignItems(NSString *target, OTFlexAlign *outValue) {
    if ([target isEqualToString:@"start"]) {
        *outValue = OTFlexAlignStart;
        return YES;
    }
    if ([target isEqualToString:@"end"]) {
        *outValue = OTFlexAlignEnd;
        return YES;
    }
    if ([target isEqualToString:@"center"]) {
        *outValue = OTFlexAlignCenter;
        return YES;
    }
    if ([target isEqualToString:@"baseline"]) {
        *outValue = OTFlexAlignBaseline;
        return YES;
    }
    if ([target isEqualToString:@"stretch"]) {
        *outValue = OTFlexAlignStretch;
        return YES;
    }
    return NO;
}

static BOOL OTParseAlignSelf(NSString *target, OTFlexAlignSelf *outValue) {
    if ([target isEqualToString:@"start"]) {
        *outValue = OTFlexAlignSelfStart;
        return YES;
    }
    if ([target isEqualToString:@"end"]) {
        *outValue = OTFlexAlignSelfEnd;
        return YES;
    }
    if ([target isEqualToString:@"center"]) {
        *outValue = OTFlexAlignSelfCenter;
        return YES;
    }
    if ([target isEqualToString:@"stretch"]) {
        *outValue = OTFlexAlignSelfStretch;
        return YES;
    }
    return NO;
}

static BOOL OTParseFlexWrap(NSString *target, OTFlexWrapMode *outValue) {
    if ([target isEqualToString:@"wrap"]) {
        *outValue = OTFlexWrapWrap;
        return YES;
    }
    if ([target isEqualToString:@"nowrap"]) {
        *outValue = OTFlexWrapNone;
        return YES;
    }
    return NO;
}

static BOOL OTBoundSize(NSString *width,
                        NSString *height,
                        float windowWidthPoints,
                        BOOL *hasSize,
                        OTSize **outWidth,
                        OTSize **outHeight,
                        NSError **error) {
    if (!width && !height) {
        *hasSize = NO;
        *outWidth = nil;
        *outHeight = nil;
        return YES;
    }
    OTSize *parsedWidth = nil;
    OTSize *parsedHeight = nil;
    if (width) {
        parsedWidth = [OTSize sizeWithString:width windowWidthPoints:windowWidthPoints error:error];
        if (!parsedWidth) {
            return NO;
        }
    }
    if (height) {
        parsedHeight = [OTSize sizeWithString:height windowWidthPoints:windowWidthPoints error:error];
        if (!parsedHeight) {
            return NO;
        }
    }
    *hasSize = YES;
    *outWidth = parsedWidth;
    *outHeight = parsedHeight;
    return YES;
}

@implementation OTFlexBox

- (instancetype)init {
    self = [super init];
    if (self) {
        _display = OTFlexDisplayFlex;
        _width = [OTSize undefinedSize];
        _height = [OTSize undefinedSize];
    }
    return self;
}

+ (nullable OTFlexBox *)flexBoxWithViewName:(NSString *)viewName
                                     fields:(NSDictionary<NSString *, NSString *> *)fields
                         windowWidthPoints:(float)windowWidthPoints
                                      error:(NSError **)error {
    OTFlexBox *box = [[OTFlexBox alloc] init];
    box.display = [fields[[TemplateKey ATTR_VISIBLE]] isEqualToString:@"false"] ? OTFlexDisplayNone : OTFlexDisplayFlex;

    OTSize *width = [OTSize sizeWithString:fields[[TemplateKey ATTR_WIDTH]] ?: @"0"
                       windowWidthPoints:windowWidthPoints
                                   error:error];
    if (!width) {
        return nil;
    }
    OTSize *height = [OTSize sizeWithString:fields[[TemplateKey ATTR_HEIGHT]] ?: @"0"
                        windowWidthPoints:windowWidthPoints
                                    error:error];
    if (!height) {
        return nil;
    }
    box.width = width;
    box.height = height;

    OTEdgeSizes *padding = nil;
    if (!OTEdgeSizesCreate(fields[[TemplateKey ATTR_PADDING]],
                           fields[[TemplateKey ATTR_PADDING_START]],
                           fields[[TemplateKey ATTR_PADDING_END]],
                           fields[[TemplateKey ATTR_PADDING_TOP]],
                           fields[[TemplateKey ATTR_PADDING_BOTTOM]],
                           windowWidthPoints,
                           &padding,
                           error)) {
        return nil;
    }
    box.padding = padding;

    OTEdgeSizes *margin = nil;
    if (!OTEdgeSizesCreate(fields[[TemplateKey ATTR_MARGIN]],
                           fields[[TemplateKey ATTR_MARGIN_START]],
                           fields[[TemplateKey ATTR_MARGIN_END]],
                           fields[[TemplateKey ATTR_MARGIN_TOP]],
                           fields[[TemplateKey ATTR_MARGIN_BOTTOM]],
                           windowWidthPoints,
                           &margin,
                           error)) {
        return nil;
    }
    box.margin = margin;

    BOOL hasMin = NO;
    OTSize *minWidth = nil;
    OTSize *minHeight = nil;
    if (!OTBoundSize(fields[[TemplateKey ATTR_MIN_WIDTH]],
                     fields[[TemplateKey ATTR_MIN_HEIGHT]],
                     windowWidthPoints,
                     &hasMin,
                     &minWidth,
                     &minHeight,
                     error)) {
        return nil;
    }
    box.hasMinSize = hasMin;
    box.minWidth = minWidth;
    box.minHeight = minHeight;

    BOOL hasMax = NO;
    OTSize *maxWidth = nil;
    OTSize *maxHeight = nil;
    if (!OTBoundSize(fields[[TemplateKey ATTR_MAX_WIDTH]],
                     fields[[TemplateKey ATTR_MAX_HEIGHT]],
                     windowWidthPoints,
                     &hasMax,
                     &maxWidth,
                     &maxHeight,
                     error)) {
        return nil;
    }
    box.hasMaxSize = hasMax;
    box.maxWidth = maxWidth;
    box.maxHeight = maxHeight;

    float grow = 0;
    box.flexGrow = OTLayoutParseFloat(fields[[TemplateKey ATTR_FLEX_GROW]] ?: @"", &grow) ? grow : 0;

    float ratio = 0;
    NSString *aspect = fields[[TemplateKey ATTR_ASPECT_RATIO]];
    if (aspect && OTLayoutParseFloat(aspect, &ratio)) {
        box.hasAspectRatio = YES;
        box.aspectRatio = ratio;
    }

    OTFlexAlignSelf alignSelf = OTFlexAlignSelfAuto;
    NSString *alignSelfText = fields[[TemplateKey ATTR_ALIGN_SELF]];
    if (alignSelfText && OTParseAlignSelf(alignSelfText, &alignSelf)) {
        box.hasAlignSelf = YES;
        box.alignSelf = alignSelf;
    }

    // `ColumnAttr.flexDirection` is Column. `RowAttr.flexDirection` is Row.
    // Other views leave the stretch default, which is Row.
    BOOL isColumn = [viewName isEqualToString:[TemplateKey COLUMN]];
    BOOL isRow = [viewName isEqualToString:[TemplateKey ROW]];
    if (isColumn) {
        box.hasFlexDirection = YES;
        box.flexDirection = OTFlexMainColumn;
    } else if (isRow) {
        box.hasFlexDirection = YES;
        box.flexDirection = OTFlexMainRow;
    }
    if (isColumn || isRow) {
        OTFlexJustify justify = OTFlexJustifyStart;
        NSString *justifyText = fields[[TemplateKey FLEXBOX_ATTR_JUSTIFY_CONTENT]];
        if (justifyText && OTParseJustify(justifyText, &justify)) {
            box.hasJustifyContent = YES;
            box.justifyContent = justify;
        }
        OTFlexAlign align = OTFlexAlignStretch;
        NSString *alignText = fields[[TemplateKey FLEXBOX_ATTR_ALIGN_ITEMS]];
        if (alignText && OTParseAlignItems(alignText, &align)) {
            box.hasAlignItems = YES;
            box.alignItems = align;
        }
        OTFlexWrapMode wrap = OTFlexWrapNone;
        NSString *wrapText = fields[[TemplateKey ATTR_FLEX_WRAP]];
        if (wrapText && OTParseFlexWrap(wrapText, &wrap)) {
            box.hasFlexWrap = YES;
            box.flexWrap = wrap;
        }
    }
    return box;
}

- (OTStretchStyle *)makeStyle {
    StretchStyleDimension undefined = OTDimenUndefined();
    StretchStyleRect undefinedRect = OTStretchRect(undefined, undefined, undefined, undefined);
    StretchStyleDimension autoDimension = OTDimenAuto();
    StretchStyleSize autoSize = OTStretchSize(autoDimension, autoDimension);
    StretchStyleSize minSize = self.hasMinSize
        ? OTStretchSize(OTDimensionOrAuto(self.minWidth), OTDimensionOrAuto(self.minHeight))
        : autoSize;
    StretchStyleSize maxSize = self.hasMaxSize
        ? OTStretchSize(OTDimensionOrAuto(self.maxWidth), OTDimensionOrAuto(self.maxHeight))
        : autoSize;
    // `app.visly.stretch.Style` defaults flexShrink to 0. StretchKit defaults
    // it to 1. Otter never assigns flexShrink. The other unset Style.init
    // fields stay on the StretchKit defaults: relative, inherit, hidden,
    // alignContent flexStart, undefined position and border, flexBasis auto.
    return [[OTStretchStyle alloc] initWithDisplay:self.display
                                      positionType:OTFlexPositionRelative
                                         direction:OTFlexDirectionInherit
                                     flexDirection:self.hasFlexDirection ? self.flexDirection : OTFlexMainRow
                                          flexWrap:self.hasFlexWrap ? self.flexWrap : OTFlexWrapNone
                                          overflow:OTFlexOverflowHidden
                                        alignItems:self.hasAlignItems ? self.alignItems : OTFlexAlignStretch
                                         alignSelf:self.hasAlignSelf ? self.alignSelf : OTFlexAlignSelfAuto
                                      alignContent:OTFlexAlignContentStart
                                    justifyContent:self.hasJustifyContent ? self.justifyContent : OTFlexJustifyStart
                                          position:undefinedRect
                                            margin:OTEdgeRect(self.margin)
                                           padding:OTEdgeRect(self.padding)
                                            border:undefinedRect
                                          flexGrow:self.flexGrow
                                        flexShrink:0
                                         flexBasis:OTDimenAuto()
                                              size:OTStretchSize([self.width dimension], [self.height dimension])
                                           minSize:minSize
                                           maxSize:maxSize
                                       aspectRatio:self.hasAspectRatio ? self.aspectRatio : (float)NAN];
}

@end
