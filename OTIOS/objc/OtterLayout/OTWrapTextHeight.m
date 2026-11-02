#import "OTWrapTextHeight.h"

#import "OTLayoutEngine.h"
#import "OTSize.h"
#import "TemplateKey.h"

#import <CoreText/CoreText.h>
#import <math.h>
#import <stdint.h>
#import <string.h>

#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
static CGFloat OTFontWeightBold(void) { return UIFontWeightBold; }
static CGFloat OTFontWeightMedium(void) { return UIFontWeightMedium; }
static CGFloat OTFontWeightRegular(void) { return UIFontWeightRegular; }
#else
static CGFloat OTFontWeightBold(void) { return (CGFloat)0.4; }
static CGFloat OTFontWeightMedium(void) { return (CGFloat)0.23; }
static CGFloat OTFontWeightRegular(void) { return (CGFloat)0.0; }
#endif

typedef struct {
    BOOL hasWidth;
    float width;
    BOOL hasHeight;
    float height;
} OTMeasuredBox;

static BOOL OTIsWrap(NSString *value) {
    return [value isEqualToString:@"wrap"] || [value isEqualToString:[TemplateKey OT_WRAP_CONTENT]];
}

static BOOL OTEdgeLength(NSString *specific,
                         NSString *uniform,
                         float windowWidthPoints,
                         int64_t *outLength,
                         NSError **error) {
    NSString *raw = specific ?: uniform;
    if (!raw) {
        *outLength = 0;
        return YES;
    }
    OTSize *size = [OTSize sizeWithString:raw windowWidthPoints:windowWidthPoints error:error];
    if (!size) {
        return NO;
    }
    *outLength = [size valueInt];
    return YES;
}

static BOOL OTMaxWidthForWrap(OTLayoutNode *node,
                              float viewportWidth,
                              float windowWidthPoints,
                              BOOL *hasWidth,
                              float *outWidth,
                              NSError **error) {
    *hasWidth = NO;
    *outWidth = 0;
    OTLayoutNode *parent = node.parent;
    if (!parent || !parent.layout || !(parent.layout.width > 0)) {
        if (viewportWidth > 0) {
            *hasWidth = YES;
            *outWidth = viewportWidth;
        }
        return YES;
    }
    OTEdgeSizes *padding = nil;
    if (!OTEdgeSizesCreate(parent.fields[[TemplateKey ATTR_PADDING]],
                           parent.fields[[TemplateKey ATTR_PADDING_START]],
                           parent.fields[[TemplateKey ATTR_PADDING_END]],
                           parent.fields[[TemplateKey ATTR_PADDING_TOP]],
                           parent.fields[[TemplateKey ATTR_PADDING_BOTTOM]],
                           windowWidthPoints,
                           &padding,
                           error)) {
        return NO;
    }
    int64_t start = padding ? [padding.start valueInt] : 0;
    int64_t end = padding ? [padding.end valueInt] : 0;
    int64_t marginStart = 0;
    int64_t marginEnd = 0;
    if (!OTEdgeLength(node.fields[[TemplateKey ATTR_MARGIN_START]],
                      node.fields[[TemplateKey ATTR_MARGIN]],
                      windowWidthPoints,
                      &marginStart,
                      error) ||
        !OTEdgeLength(node.fields[[TemplateKey ATTR_MARGIN_END]],
                      node.fields[[TemplateKey ATTR_MARGIN]],
                      windowWidthPoints,
                      &marginEnd,
                      error)) {
        return NO;
    }
    float available = parent.layout.width - (float)(start + end + marginStart + marginEnd);
    if (available > 0) {
        *hasWidth = YES;
        *outWidth = available;
    }
    return YES;
}

static BOOL OTParseLayoutInt(NSString *text, int64_t *outValue) {
    const char *cursor = text.UTF8String;
    if (cursor == NULL || *cursor == '\0') {
        return NO;
    }
    int sign = 1;
    if (*cursor == '+') {
        cursor++;
    } else if (*cursor == '-') {
        sign = -1;
        cursor++;
    }
    if (*cursor < '0' || *cursor > '9') {
        return NO;
    }
    uint64_t magnitude = 0;
    while (*cursor >= '0' && *cursor <= '9') {
        uint64_t digit = (uint64_t)(*cursor - '0');
        if (magnitude > (UINT64_MAX - digit) / 10) {
            return NO;
        }
        magnitude = magnitude * 10 + digit;
        cursor++;
    }
    if (*cursor != '\0') {
        return NO;
    }
    if (sign > 0) {
        if (magnitude > (uint64_t)INT64_MAX) {
            return NO;
        }
        *outValue = (int64_t)magnitude;
        return YES;
    }
    if (magnitude > (uint64_t)INT64_MAX + 1) {
        return NO;
    }
    *outValue = magnitude == (uint64_t)INT64_MAX + 1 ? INT64_MIN : -(int64_t)magnitude;
    return YES;
}

static int64_t OTLineLimit(NSDictionary<NSString *, NSString *> *fields) {
    NSString *maxLines = fields[[TemplateKey ATTR_MAX_LINES]];
    int64_t parsed = 0;
    if (maxLines && OTParseLayoutInt(maxLines, &parsed) && parsed > 0) {
        return parsed;
    }
    if ([fields[[TemplateKey ATTR_ELLIPSIS]] isEqualToString:@"true"]) {
        return 1;
    }
    return 0;
}

static CTFontRef OTSystemFont(CGFloat size, NSString *weightName) {
    NSString *trimmed = [weightName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    CGFloat weight = OTFontWeightRegular();
    if ([trimmed isEqualToString:@"bold"]) {
        weight = OTFontWeightBold();
    } else if ([trimmed isEqualToString:@"medium"]) {
        weight = OTFontWeightMedium();
    }
    CTFontRef base = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, size, NULL);
    if (!base) {
        base = CTFontCreateWithName(CFSTR("HelveticaNeue"), size, NULL);
    }
    if (!base) {
        return NULL;
    }
    CFStringRef family = CTFontCopyFamilyName(base);
    CFRelease(base);
    if (!family) {
        return CTFontCreateWithName(CFSTR("HelveticaNeue"), size, NULL);
    }
    NSDictionary *attributes = @{
        (__bridge id)kCTFontFamilyNameAttribute: (__bridge id)family,
        (__bridge id)kCTFontTraitsAttribute: @{
            (__bridge id)kCTFontWeightTrait: @(weight)
        }
    };
    CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithAttributes((__bridge CFDictionaryRef)attributes);
    CTFontRef font = CTFontCreateWithFontDescriptor(descriptor, size, NULL);
    CFRelease(descriptor);
    CFRelease(family);
    return font;
}

static CGFloat OTLineWidth(CTLineRef line) {
    CGFloat ascent = 0;
    CGFloat descent = 0;
    CGFloat leading = 0;
    double typographic = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
    return (CGFloat)typographic + CTLineGetTrailingWhitespaceWidth(line);
}

/// `includeFontPadding = false`, line spacing 0 / multiplier 1, and fallback
/// glyph bounds. Weight follows bold, medium (500), or normal.
static void OTMeasureText(NSString *text,
                          CTFontRef font,
                          int64_t contentWidth,
                          int64_t maxLines,
                          CGFloat *outLineWidth,
                          int64_t *outLayoutHeight) {
    int64_t oneLine = (int64_t)ceil((double)(CTFontGetAscent(font) + CTFontGetDescent(font)));
    if (oneLine < 1) {
        oneLine = 1;
    }
    NSAttributedString *attributed = [[NSAttributedString alloc] initWithString:text ?: @""
                                                                     attributes:@{
        (id)kCTFontAttributeName: (__bridge id)font
    }];
    if (contentWidth <= 0) {
        CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)attributed);
        *outLineWidth = line ? OTLineWidth(line) : 0;
        *outLayoutHeight = oneLine;
        if (line) {
            CFRelease(line);
        }
        return;
    }
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)attributed);
    if (!framesetter) {
        *outLineWidth = 0;
        *outLayoutHeight = oneLine;
        return;
    }
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, CGRectMake(0, 0, (CGFloat)contentWidth, (CGFloat)1000000));
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
    CFArrayRef rawLines = frame ? CTFrameGetLines(frame) : NULL;
    CFIndex count = rawLines ? CFArrayGetCount(rawLines) : 0;
    CFIndex used = count;
    if (maxLines > 0 && used > maxLines) {
        used = (CFIndex)maxLines;
    }
    if (used <= 0) {
        *outLineWidth = 0;
        *outLayoutHeight = oneLine;
    } else {
        CGFloat widest = 0;
        CGFloat total = 0;
        for (CFIndex index = 0; index < used; index++) {
            CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(rawLines, index);
            if (!line) {
                continue;
            }
            CGFloat width = OTLineWidth(line);
            if (width > widest) {
                widest = width;
            }
            CGFloat ascent = 0;
            CGFloat descent = 0;
            CGFloat leading = 0;
            CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
            total += ascent + descent;
        }
        int64_t layoutHeight = (int64_t)ceil((double)total);
        if (layoutHeight < oneLine) {
            layoutHeight = oneLine;
        }
        *outLineWidth = widest;
        *outLayoutHeight = layoutHeight;
    }
    if (frame) {
        CFRelease(frame);
    }
    CGPathRelease(path);
    if (framesetter) {
        CFRelease(framesetter);
    }
}

static BOOL OTMeasureNode(OTLayoutNode *node,
                          NSString *width,
                          NSString *height,
                          float viewportWidth,
                          float windowWidthPoints,
                          OTLayoutExpressionBlock expression,
                          OTMeasuredBox *measured,
                          NSError **error) {
    memset(measured, 0, sizeof(*measured));
    OTEdgeSizes *padding = nil;
    if (!OTEdgeSizesCreate(node.fields[[TemplateKey ATTR_PADDING]],
                           node.fields[[TemplateKey ATTR_PADDING_START]],
                           node.fields[[TemplateKey ATTR_PADDING_END]],
                           node.fields[[TemplateKey ATTR_PADDING_TOP]],
                           node.fields[[TemplateKey ATTR_PADDING_BOTTOM]],
                           windowWidthPoints,
                           &padding,
                           error)) {
        return NO;
    }
    int64_t start = padding ? [padding.start valueInt] : 0;
    int64_t end = padding ? [padding.end valueInt] : 0;
    int64_t top = padding ? [padding.top valueInt] : 0;
    int64_t bottom = padding ? [padding.bottom valueInt] : 0;
    BOOL wrapWidth = OTIsWrap(width);
    BOOL wrapHeight = OTIsWrap(height);
    BOOL laidOutPositive = node.layout && node.layout.width > 0;
    float maxBox = 0;
    if (wrapWidth || !laidOutPositive) {
        BOOL hasMax = NO;
        float maxWidth = 0;
        if (!OTMaxWidthForWrap(node, viewportWidth, windowWidthPoints, &hasMax, &maxWidth, error)) {
            return NO;
        }
        if (hasMax) {
            maxBox = maxWidth;
        } else if (laidOutPositive) {
            maxBox = node.layout.width;
        }
    } else {
        maxBox = node.layout.width;
    }
    int64_t rounded = OTJavaRoundToInt(maxBox - (float)(start + end));
    int64_t contentWidth = rounded > 0 ? rounded : 0;
    // Page settle passes an empty item, same as `OTEngine.createNodeTree`.
    NSString *text = OTExtractExpValue(node.fields[[TemplateKey ATTR_TEXT]] ?: @"", @{}, expression);
    NSString *textSizeRaw = node.fields[[TemplateKey ATTR_TEXT_SIZE]] ?: @"12px";
    OTSize *textSize = [OTSize sizeWithString:textSizeRaw windowWidthPoints:windowWidthPoints error:error];
    if (!textSize) {
        return NO;
    }
    float fontSize = [textSize valueFloat];
    if (fontSize < 1.0f) {
        fontSize = 1.0f;
    }
    CTFontRef font = OTSystemFont((CGFloat)fontSize, node.fields[[TemplateKey ATTR_FONT_WEIGHT]]);
    if (!font) {
        if (error) {
            *error = OTLayoutErrorMake(@"text font could not be created");
        }
        return NO;
    }
    CGFloat lineWidth = 0;
    int64_t layoutHeight = 0;
    OTMeasureText(text, font, contentWidth, OTLineLimit(node.fields), &lineWidth, &layoutHeight);
    CFRelease(font);
    if (wrapWidth) {
        float wanted = (float)ceil((double)lineWidth) + (float)(start + end);
        measured->hasWidth = YES;
        measured->width = maxBox > 0 ? (wanted < maxBox ? wanted : maxBox) : wanted;
    }
    if (wrapHeight) {
        measured->hasHeight = YES;
        measured->height = (float)(layoutHeight + top + bottom);
    }
    return YES;
}

// OTStretchStyle does not expose size, so the flex box keeps the style that
// was sent to stretch. Rebuilding it writes the measured points and leaves
// flexShrink at 0.
static BOOL OTAssignSize(OTLayoutNode *node, OTMeasuredBox measured) {
    if (!measured.hasWidth && !measured.hasHeight) {
        return NO;
    }
    OTFlexBox *box = node.flexBox;
    StretchStyleDimension nextWidth = measured.hasWidth ? OTDimenPoints(measured.width) : [box.width dimension];
    StretchStyleDimension nextHeight = measured.hasHeight ? OTDimenPoints(measured.height) : [box.height dimension];
    if (OTSameStretchDimension([box.width dimension], nextWidth) &&
        OTSameStretchDimension([box.height dimension], nextHeight)) {
        return NO;
    }
    if (measured.hasWidth) {
        box.width = [OTSize sizeWithPoints:measured.width];
    }
    if (measured.hasHeight) {
        box.height = [OTSize sizeWithPoints:measured.height];
    }
    node.stretch.style = [box makeStyle];
    return YES;
}

static BOOL OTWrapApply(OTLayoutNode *node,
                        float viewportWidth,
                        float windowWidthPoints,
                        OTLayoutExpressionBlock expression,
                        BOOL *changed,
                        NSError **error) {
    BOOL didChange = NO;
    if ([node.viewName isEqualToString:[TemplateKey TEXT]]) {
        NSString *width = node.fields[[TemplateKey ATTR_WIDTH]] ?: @"0";
        NSString *height = node.fields[[TemplateKey ATTR_HEIGHT]] ?: @"0";
        if (OTIsWrap(width) || OTIsWrap(height)) {
            OTMeasuredBox measured;
            if (!OTMeasureNode(node, width, height, viewportWidth, windowWidthPoints, expression, &measured, error)) {
                return NO;
            }
            if (OTAssignSize(node, measured)) {
                didChange = YES;
            }
        }
    }
    for (OTLayoutNode *child in node.children) {
        BOOL childChanged = NO;
        if (!OTWrapApply(child, viewportWidth, windowWidthPoints, expression, &childChanged, error)) {
            return NO;
        }
        if (childChanged) {
            didChange = YES;
        }
    }
    *changed = didChange;
    return YES;
}

BOOL OTWrapTextHeightSettle(OTLayoutNode *root,
                            CGSize viewport,
                            float windowWidthPoints,
                            OTLayoutExpressionBlock expression,
                            BOOL (^compute)(NSError **error),
                            NSError **error) {
    if (compute && !compute(error)) {
        return NO;
    }
    int guardCount = 0;
    while (guardCount < 4) {
        BOOL changed = NO;
        if (!OTWrapApply(root, (float)viewport.width, windowWidthPoints, expression, &changed, error)) {
            return NO;
        }
        if (!changed) {
            break;
        }
        if (compute && !compute(error)) {
            return NO;
        }
        guardCount += 1;
    }
    return YES;
}
