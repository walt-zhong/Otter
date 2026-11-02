#import "OTSize.h"

#import "OTLayoutEngine.h"
#import "ScreenAdapt.h"
#import "TemplateKey.h"

#import <locale.h>
#import <math.h>
#import <stdint.h>
#import <xlocale.h>

static float OTAdaptDpToPoints(float dp, float windowWidthPoints);
static float OTAdaptPtToPoints(float pt, float windowWidthPoints);

typedef NS_ENUM(NSInteger, OTSizeKind) {
    OTSizeKindPoints = 0,
    OTSizeKindPercent,
    OTSizeKindAuto,
    OTSizeKindUndefined,
};

@interface OTSize ()
@property (nonatomic, assign) OTSizeKind kind;
@property (nonatomic, assign, readwrite) float value;
@end

@implementation OTSize

+ (OTSize *)sizeWithKind:(OTSizeKind)kind value:(float)value {
    OTSize *size = [[OTSize alloc] init];
    size.kind = kind;
    size.value = value;
    return size;
}

+ (OTSize *)sizeWithPoints:(float)value {
    return [self sizeWithKind:OTSizeKindPoints value:value];
}

+ (OTSize *)sizeWithPercent:(float)value {
    return [self sizeWithKind:OTSizeKindPercent value:value];
}

+ (OTSize *)autoSize {
    return [self sizeWithKind:OTSizeKindAuto value:0];
}

+ (OTSize *)undefinedSize {
    return [self sizeWithKind:OTSizeKindUndefined value:0];
}

+ (nullable OTSize *)sizeWithString:(NSString *)raw
                 windowWidthPoints:(float)windowWidthPoints
                             error:(NSError **)error {
    NSString *value = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
    if ([value hasSuffix:[TemplateKey OT_PX]]) {
        NSString *number = [value substringToIndex:value.length - [TemplateKey OT_PX].length];
        float parsed = 0;
        if (!OTLayoutParseFloat(number, &parsed)) {
            if (error) {
                *error = OTLayoutErrorMake([NSString stringWithFormat:@"size is not a number: %@", number]);
            }
            return nil;
        }
        return [OTSize sizeWithPoints:OTAdaptDpToPoints(parsed, windowWidthPoints)];
    }
    if ([value hasSuffix:[TemplateKey OT_PT]]) {
        NSString *number = [value substringToIndex:value.length - [TemplateKey OT_PT].length];
        float parsed = 0;
        if (!OTLayoutParseFloat(number, &parsed)) {
            if (error) {
                *error = OTLayoutErrorMake([NSString stringWithFormat:@"size is not a number: %@", number]);
            }
            return nil;
        }
        return [OTSize sizeWithPoints:OTAdaptPtToPoints(parsed, windowWidthPoints)];
    }
    if ([value hasSuffix:[TemplateKey OT_PE]]) {
        NSString *number = [value substringToIndex:value.length - [TemplateKey OT_PE].length];
        float parsed = 0;
        if (!OTLayoutParseFloat(number, &parsed)) {
            if (error) {
                *error = OTLayoutErrorMake([NSString stringWithFormat:@"size is not a number: %@", number]);
            }
            return nil;
        }
        return [OTSize sizeWithPercent:parsed / 100.0f];
    }
    if ([value isEqualToString:[TemplateKey OT_WRAP_CONTENT]]) {
        return [OTSize autoSize];
    }
    if ([value isEqualToString:[TemplateKey OT_MATCH_PARENT]]) {
        return [OTSize sizeWithPercent:1];
    }
    if (value.length > 0) {
        float parsed = 0;
        if (OTLayoutParseFloat(value, &parsed)) {
            return [OTSize sizeWithPoints:OTAdaptDpToPoints(parsed, windowWidthPoints)];
        }
        // `ExpansionCenter.extensionSize` is not installed on iOS. Android
        // then returns `OTSize.Undefined`.
        return [OTSize undefinedSize];
    }
    return [OTSize undefinedSize];
}

- (StretchStyleDimension)dimension {
    switch (self.kind) {
        case OTSizeKindPoints:
            return OTDimenPoints(self.value);
        case OTSizeKindPercent:
            return OTDimenPercent(self.value);
        case OTSizeKindAuto:
            return OTDimenAuto();
        case OTSizeKindUndefined:
            return OTDimenUndefined();
    }
    return OTDimenUndefined();
}

- (int64_t)valueInt {
    switch (self.kind) {
        case OTSizeKindPoints:
        case OTSizeKindPercent:
            return OTTruncTowardZero(self.value);
        case OTSizeKindAuto:
        case OTSizeKindUndefined:
            return 0;
    }
    return 0;
}

- (float)valueFloat {
    switch (self.kind) {
        case OTSizeKindPoints:
        case OTSizeKindPercent:
            return self.value;
        case OTSizeKindAuto:
        case OTSizeKindUndefined:
            return 0;
    }
    return 0;
}

@end

/// JSON numbers are dp. Density is 1 because UIKit layout is already in points:
/// round(dp * ScreenAdapt.scaleFor(windowWidthPoints)).
static float OTAdaptDpToPoints(float dp, float windowWidthPoints) {
    float scale = (float)[ScreenAdapt scaleForWindowWidth:(CGFloat)windowWidthPoints];
    float density = 1.0f;
    return (float)OTJavaRoundToInt(dp * scale * density);
}

/// `OTSize.ptToPx`: round(pt * (windowWidthDp / DESIGN_WIDTH_DP)). This path
/// does not clamp through `scaleForWindowWidth:`.
static float OTAdaptPtToPoints(float pt, float windowWidthPoints) {
    float design = (float)[ScreenAdapt DESIGN_WIDTH_DP];
    float ratio = (windowWidthPoints > 0.0f && design > 0.0f) ? windowWidthPoints / design : 1.0f;
    return (float)OTJavaRoundToInt(pt * ratio);
}

int64_t OTJavaRoundToInt(float value) {
    if (!isfinite(value)) {
        return 0;
    }
    double rounded = floor((double)value + 0.5);
    if (rounded >= (double)INT64_MAX) {
        return INT64_MAX;
    }
    if (rounded <= (double)INT64_MIN) {
        return INT64_MIN;
    }
    return (int64_t)rounded;
}

int64_t OTTruncTowardZero(float value) {
    if (!isfinite(value)) {
        return 0;
    }
    if (value >= (float)INT64_MAX) {
        return INT64_MAX;
    }
    if (value <= (float)INT64_MIN) {
        return INT64_MIN;
    }
    return (int64_t)value;
}

static locale_t OTLayoutCLocale(void) {
    static locale_t locale;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        locale = newlocale(LC_ALL_MASK, "C", NULL);
    });
    return locale;
}

BOOL OTLayoutParseFloat(NSString *text, float *outValue) {
    if (outValue) {
        *outValue = 0;
    }
    if (text.length == 0) {
        return NO;
    }
    const char *utf8 = text.UTF8String;
    if (utf8 == NULL || utf8[0] == '\0') {
        return NO;
    }
    unsigned char first = (unsigned char)utf8[0];
    if (first == ' ' || first == '\t' || first == '\n' || first == '\r' || first == '\f' || first == '\v') {
        return NO;
    }
    char *end = NULL;
    float value = strtof_l(utf8, &end, OTLayoutCLocale());
    if (end == utf8 || end == NULL || *end != '\0') {
        return NO;
    }
    if (outValue) {
        *outValue = value;
    }
    return YES;
}
