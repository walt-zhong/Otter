#import "OTAttrBinding.h"

#import "OTUnevaluatedKeys.h"
#import "TemplateKey.h"

#import <locale.h>
#import <math.h>
#import <stdlib.h>
#import <string.h>
#import <xlocale.h>

static locale_t OTBindingCLocale(void) {
    static locale_t locale;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        locale = newlocale(LC_ALL_MASK, "C", NULL);
    });
    return locale;
}

static NSString *OTSwiftDoubleString(double value) {
    if (isnan(value)) {
        return @"nan";
    }
    if (isinf(value)) {
        return signbit(value) ? @"-inf" : @"inf";
    }
    if (value == 0.0) {
        return signbit(value) ? @"-0.0" : @"0.0";
    }

    int negative = signbit(value);
    double magnitude = fabs(value);
    char raw[128];
    int precision = 1;
    locale_t locale = OTBindingCLocale();
    for (; precision <= 17; precision++) {
        snprintf_l(raw, sizeof raw, locale, "%.*e", precision - 1, magnitude);
        char *end = NULL;
        double back = strtod_l(raw, &end, locale);
        if (end != NULL && *end == '\0' && back == magnitude) {
            break;
        }
    }

    const char *cursor = raw;
    char digits[64];
    int count = 0;
    if (*cursor == '-' || *cursor == '+') {
        cursor++;
    }
    if (*cursor >= '0' && *cursor <= '9') {
        digits[count++] = *cursor++;
    }
    if (*cursor == '.') {
        cursor++;
        while (*cursor >= '0' && *cursor <= '9' && count < (int)sizeof(digits) - 1) {
            digits[count++] = *cursor++;
        }
    }
    digits[count] = '\0';
    int exponent = 0;
    if (*cursor == 'e' || *cursor == 'E') {
        cursor++;
        exponent = atoi(cursor);
    }
    while (count > 1 && digits[count - 1] == '0') {
        digits[--count] = '\0';
    }
    if (count == 0) {
        return negative ? @"-0.0" : @"0.0";
    }

    char body[160];
    if (exponent < -4 || exponent >= 16) {
        if (count == 1) {
            snprintf(body, sizeof body, "%ce%+03d", digits[0], exponent);
        } else {
            char fraction[64];
            memcpy(fraction, digits + 1, (size_t)(count - 1));
            fraction[count - 1] = '\0';
            snprintf(body, sizeof body, "%c.%se%+03d", digits[0], fraction, exponent);
        }
    } else if (exponent >= 0) {
        if (exponent >= count - 1) {
            int zeros = exponent - (count - 1);
            int used = 0;
            for (int index = 0; index < count; index++) {
                body[used++] = digits[index];
            }
            for (int index = 0; index < zeros; index++) {
                body[used++] = '0';
            }
            body[used++] = '.';
            body[used++] = '0';
            body[used] = '\0';
        } else {
            int used = 0;
            for (int index = 0; index <= exponent; index++) {
                body[used++] = digits[index];
            }
            body[used++] = '.';
            for (int index = exponent + 1; index < count; index++) {
                body[used++] = digits[index];
            }
            body[used] = '\0';
        }
    } else {
        int used = 0;
        body[used++] = '0';
        body[used++] = '.';
        int zeros = -exponent - 1;
        for (int index = 0; index < zeros; index++) {
            body[used++] = '0';
        }
        for (int index = 0; index < count; index++) {
            body[used++] = digits[index];
        }
        body[used] = '\0';
    }
    if (negative) {
        return [@"-" stringByAppendingString:[NSString stringWithUTF8String:body]];
    }
    return [NSString stringWithUTF8String:body];
}

static NSString *OTJSONString(id value) {
    if (![NSJSONSerialization isValidJSONObject:value]) {
        return nil;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:value options:0 error:nil];
    if (!data) {
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

static NSDictionary *OTAsDictionary(id value) {
    if (![value isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[(NSDictionary *)value count]];
    for (id key in (NSDictionary *)value) {
        if (![key isKindOfClass:[NSString class]]) {
            return nil;
        }
        result[key] = ((NSDictionary *)value)[key];
    }
    return [result copy];
}

static NSArray *OTCoerceObjectArray(id value) {
    if (![value isKindOfClass:[NSArray class]]) {
        return nil;
    }
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:[(NSArray *)value count]];
    for (id element in (NSArray *)value) {
        NSDictionary *object = OTAsDictionary(element);
        if (!object) {
            return nil;
        }
        [items addObject:object];
    }
    return [items copy];
}

static NSArray *OTParseListJSON(NSString *text) {
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        return nil;
    }
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (!json) {
        return nil;
    }
    return OTCoerceObjectArray(json);
}

static NSString *OTKotlinString(id value) {
    if (value == (id)kCFNull || [value isKindOfClass:[NSNull class]]) {
        return @"null";
    }
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSString *json = OTJSONString(value);
        if (json) {
            return json;
        }
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSString *json = OTJSONString(value);
        if (json) {
            return json;
        }
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *number = value;
        if (CFGetTypeID((__bridge CFTypeRef)number) == CFBooleanGetTypeID()) {
            return number.boolValue ? @"true" : @"false";
        }
        const char *type = number.objCType;
        if (type != NULL && (type[0] == 'f' || type[0] == 'd') && type[1] == '\0') {
            return OTSwiftDoubleString(number.doubleValue);
        }
        return number.stringValue ?: @"";
    }
    return [value description] ?: @"";
}

static BOOL OTIsNull(id value) {
    return value == nil || value == (id)kCFNull || [value isKindOfClass:[NSNull class]];
}

static NSString *OTStringifyResult(id result, NSString *fallback) {
    if (OTIsNull(result)) {
        return fallback ?: @"";
    }
    return OTKotlinString(result);
}

NSString *OTExtractExpValue(NSString *raw,
                            id data,
                            OTLayoutExpressionBlock expression) {
    id result = expression ? expression(raw, data) : nil;
    return OTStringifyResult(result, raw ?: @"");
}

static NSArray *OTListItemsFromExpression(id value) {
    NSArray *items = OTCoerceObjectArray(value);
    if (items) {
        return items;
    }
    NSString *text = OTJSONString(value);
    if (!text) {
        return nil;
    }
    return OTParseListJSON(text);
}

static BOOL OTParseInt(NSString *text, int64_t *outValue) {
    if (text.length == 0) {
        return NO;
    }
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
    if (magnitude == (uint64_t)INT64_MAX + 1) {
        *outValue = INT64_MIN;
        return YES;
    }
    *outValue = -(int64_t)magnitude;
    return YES;
}

static NSString *OTPositiveIntString(NSString *raw) {
    int64_t number = 0;
    if (!raw || !OTParseInt(raw, &number) || number <= 0) {
        return nil;
    }
    return [NSString stringWithFormat:@"%lld", number];
}

static void OTApplyAttrDefaults(NSString *viewName, NSMutableDictionary<NSString *, NSString *> *fields) {
    if (!fields[[TemplateKey ATTR_WIDTH]]) {
        fields[[TemplateKey ATTR_WIDTH]] = @"0";
    }
    if (!fields[[TemplateKey ATTR_HEIGHT]]) {
        fields[[TemplateKey ATTR_HEIGHT]] = @"0";
    }

    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    if ([viewName isEqualToString:[TemplateKey TEXT]]) {
        if (!fields[[TemplateKey ATTR_TEXT]]) {
            fields[[TemplateKey ATTR_TEXT]] = @"";
        }
        if (!fields[[TemplateKey ATTR_TEXT_COLOR]]) {
            fields[[TemplateKey ATTR_TEXT_COLOR]] = @"#000000";
        }
        if (!fields[[TemplateKey ATTR_TEXT_SIZE]]) {
            fields[[TemplateKey ATTR_TEXT_SIZE]] = @"12px";
        }
        fields[[TemplateKey ATTR_ELLIPSIS]] = [fields[[TemplateKey ATTR_ELLIPSIS]] isEqualToString:@"true"] ? @"true" : @"false";
    } else if ([viewName isEqualToString:[TemplateKey IMAGE]]) {
        if (!fields[[TemplateKey ATTR_SRC]]) {
            fields[[TemplateKey ATTR_SRC]] = @"";
        }
        NSString *fit = fields[[TemplateKey ATTR_IMAGE_FIT]] ?: @"";
        NSString *trimmed = [fit stringByTrimmingCharactersInSet:whitespace];
        fields[[TemplateKey ATTR_IMAGE_FIT]] = trimmed.length == 0 ? @"cover" : fit;
    } else if ([viewName isEqualToString:[TemplateKey INPUT]]) {
        if (!fields[[TemplateKey ATTR_TEXT]]) {
            fields[[TemplateKey ATTR_TEXT]] = @"";
        }
        if (!fields[[TemplateKey ATTR_HINT]]) {
            fields[[TemplateKey ATTR_HINT]] = @"";
        }
        if (!fields[[TemplateKey ATTR_HINT_COLOR]]) {
            fields[[TemplateKey ATTR_HINT_COLOR]] = @"#8A8178";
        }
        if (!fields[[TemplateKey ATTR_TEXT_COLOR]]) {
            fields[[TemplateKey ATTR_TEXT_COLOR]] = @"#1F1A17";
        }
        if (!fields[[TemplateKey ATTR_TEXT_SIZE]]) {
            fields[[TemplateKey ATTR_TEXT_SIZE]] = @"14px";
        }
        if (!fields[[TemplateKey ATTR_INPUT_TYPE]]) {
            fields[[TemplateKey ATTR_INPUT_TYPE]] = @"text";
        }
        fields[[TemplateKey ATTR_LINES]] = OTPositiveIntString(fields[[TemplateKey ATTR_LINES]]) ?: @"1";
    } else if ([viewName isEqualToString:[TemplateKey CHECKBOX]] ||
               [viewName isEqualToString:[TemplateKey RADIO]] ||
               [viewName isEqualToString:[TemplateKey SWITCH]]) {
        if (!fields[[TemplateKey ATTR_TEXT]]) {
            fields[[TemplateKey ATTR_TEXT]] = @"";
        }
        if (!fields[[TemplateKey ATTR_CHECKED]]) {
            fields[[TemplateKey ATTR_CHECKED]] = @"false";
        }
        if (!fields[[TemplateKey ATTR_TINT]]) {
            fields[[TemplateKey ATTR_TINT]] = @"#1F6F6A";
        }
        if (!fields[[TemplateKey ATTR_TEXT_COLOR]]) {
            fields[[TemplateKey ATTR_TEXT_COLOR]] = @"#1F1A17";
        }
        if (!fields[[TemplateKey ATTR_TEXT_SIZE]]) {
            fields[[TemplateKey ATTR_TEXT_SIZE]] = @"14px";
        }
        if ([viewName isEqualToString:[TemplateKey RADIO]] && !fields[[TemplateKey ATTR_GROUP]]) {
            fields[[TemplateKey ATTR_GROUP]] = @"";
        }
    } else if ([viewName isEqualToString:[TemplateKey PROGRESS]]) {
        if (!fields[[TemplateKey ATTR_TRAIL_COLOR]]) {
            fields[[TemplateKey ATTR_TRAIL_COLOR]] = @"red";
        }
        if (!fields[[TemplateKey ATTR_STROKE_COLOR]]) {
            fields[[TemplateKey ATTR_STROKE_COLOR]] = @"gray";
        }
        if (!fields[[TemplateKey ATTR_VALUE_MIN]]) {
            fields[[TemplateKey ATTR_VALUE_MIN]] = @"0";
        }
        if (!fields[[TemplateKey ATTR_VALUE_MAX]]) {
            fields[[TemplateKey ATTR_VALUE_MAX]] = @"1";
        }
        fields[[TemplateKey ATTR_ANIMATE_ENABLE]] = [fields[[TemplateKey ATTR_ANIMATE_ENABLE]] isEqualToString:@"true"] ? @"true" : @"false";
    } else if ([viewName isEqualToString:[TemplateKey OT_LIST]]) {
        if (!fields[[TemplateKey ATTR_LIST_DIRECTION]]) {
            fields[[TemplateKey ATTR_LIST_DIRECTION]] = @"vertical";
        }
    }

    NSString *weight = fields[[TemplateKey ATTR_FONT_WEIGHT]];
    if (weight) {
        NSString *trimmed = [weight stringByTrimmingCharactersInSet:whitespace];
        if (trimmed.length == 0) {
            [fields removeObjectForKey:[TemplateKey ATTR_FONT_WEIGHT]];
        } else {
            fields[[TemplateKey ATTR_FONT_WEIGHT]] = trimmed;
        }
    }
    NSString *maxLines = fields[[TemplateKey ATTR_MAX_LINES]];
    if (maxLines) {
        NSString *normalized = OTPositiveIntString(maxLines);
        if (normalized) {
            fields[[TemplateKey ATTR_MAX_LINES]] = normalized;
        } else {
            [fields removeObjectForKey:[TemplateKey ATTR_MAX_LINES]];
        }
    }
    NSString *placeholder = fields[[TemplateKey ATTR_PLACEHOLDER]];
    if (placeholder && [placeholder stringByTrimmingCharactersInSet:whitespace].length == 0) {
        [fields removeObjectForKey:[TemplateKey ATTR_PLACEHOLDER]];
    }
}

@implementation OTBoundAttrs

- (instancetype)init {
    self = [super init];
    if (self) {
        _fields = @{};
        _listItems = @[];
    }
    return self;
}

@end

OTBoundAttrs *OTBindAttributes(NSString *viewName,
                               NSDictionary<NSString *, NSString *> *attrs,
                               id data,
                               OTLayoutExpressionBlock expression) {
    NSString *name = viewName ?: @"";
    NSMutableDictionary<NSString *, NSString *> *fields = [NSMutableDictionary dictionary];
    [attrs enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        (void)stop;
        if (![key isKindOfClass:[NSString class]]) {
            return;
        }
        NSString *attrName = key;
        if ([name isEqualToString:[TemplateKey OT_LIST]] && [attrName isEqualToString:[TemplateKey ATTR_DATA]]) {
            return;
        }
        NSString *raw = [obj isKindOfClass:[NSString class]] ? obj : @"";
        if ([OTUnevaluatedKeys containsName:attrName]) {
            fields[attrName] = raw;
        } else {
            fields[attrName] = OTExtractExpValue(raw, data, expression);
        }
    }];

    NSArray *listItems = @[];
    if ([name isEqualToString:[TemplateKey OT_LIST]]) {
        id rawValue = attrs[[TemplateKey ATTR_DATA]];
        if ([rawValue isKindOfClass:[NSString class]]) {
            NSString *raw = rawValue;
            id resolved = expression ? expression(raw, data) : nil;
            NSArray *items = OTIsNull(resolved) ? nil : OTListItemsFromExpression(resolved);
            if (!OTIsNull(resolved) && items) {
                listItems = items;
                fields[[TemplateKey ATTR_DATA]] = OTJSONString(items) ?: OTJSONString(resolved) ?: raw;
            } else {
                NSString *stringValue = OTStringifyResult(resolved, raw);
                fields[[TemplateKey ATTR_DATA]] = stringValue;
                listItems = OTParseListJSON(stringValue) ?: @[];
            }
        }
    }

    OTApplyAttrDefaults(name, fields);
    OTBoundAttrs *bound = [[OTBoundAttrs alloc] init];
    bound.fields = fields;
    bound.scroll = [name isEqualToString:[TemplateKey COLUMN]] && [fields[[TemplateKey ATTR_SCROLL]] isEqualToString:@"true"];
    bound.glass = fields[[TemplateKey ATTR_GLASS_STYLE]] != nil;
    bound.listItems = listItems;
    return bound;
}
