#import "PageParams.h"

@implementation JSONText

+ (BOOL)isLetter:(unichar)scalar {
    return (scalar >= 'A' && scalar <= 'Z') || (scalar >= 'a' && scalar <= 'z');
}

+ (BOOL)isDigit:(unichar)scalar {
    return scalar >= '0' && scalar <= '9';
}

+ (BOOL)isName:(NSString *)text {
    if (text.length == 0) {
        return NO;
    }
    unichar first = [text characterAtIndex:0];
    if (![self isLetter:first] && first != '_') {
        return NO;
    }
    for (NSUInteger index = 1; index < text.length; index++) {
        unichar scalar = [text characterAtIndex:index];
        if (![self isLetter:scalar] && ![self isDigit:scalar] && scalar != '_') {
            return NO;
        }
    }
    return YES;
}

+ (BOOL)isHexColor:(NSString *)text {
    if (text.length == 0 || [text characterAtIndex:0] != '#') {
        return NO;
    }
    NSString *hex = [text substringFromIndex:1];
    if (hex.length != 3 && hex.length != 6 && hex.length != 8) {
        return NO;
    }
    for (NSUInteger index = 0; index < hex.length; index++) {
        unichar character = [hex characterAtIndex:index];
        BOOL digit = character >= '0' && character <= '9';
        BOOL lower = character >= 'a' && character <= 'f';
        BOOL upper = character >= 'A' && character <= 'F';
        if (!digit && !lower && !upper) {
            return NO;
        }
    }
    return YES;
}

@end

static BOOL OTIsNull(JSONValue *value) {
    return value == nil || value.kind == JSONValueKindNull;
}

static BOOL OTSameNumber(JSONNumber *left, JSONNumber *right) {
    NSString *leftText = left.description;
    NSString *rightText = right.description;
    NSLocale *locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    NSDecimalNumber *leftDecimal = [NSDecimalNumber decimalNumberWithString:leftText locale:locale];
    NSDecimalNumber *rightDecimal = [NSDecimalNumber decimalNumberWithString:rightText locale:locale];
    if ([leftDecimal isEqualToNumber:[NSDecimalNumber notANumber]] ||
        [rightDecimal isEqualToNumber:[NSDecimalNumber notANumber]]) {
        return [leftText isEqualToString:rightText];
    }
    return [leftDecimal compare:rightDecimal] == NSOrderedSame;
}

static BOOL OTSameValue(JSONValue *left, JSONValue *right) {
    BOOL leftNull = OTIsNull(left);
    BOOL rightNull = OTIsNull(right);
    if (leftNull || rightNull) {
        return leftNull && rightNull;
    }
    if (left.kind == JSONValueKindBool || right.kind == JSONValueKindBool) {
        if (left.kind != JSONValueKindBool || right.kind != JSONValueKindBool) {
            return NO;
        }
        return left.boolValue == right.boolValue;
    }
    if (left.kind == JSONValueKindNumber && right.kind == JSONValueKindNumber) {
        return OTSameNumber(left.number, right.number);
    }
    if (left.kind == JSONValueKindObject && right.kind == JSONValueKindObject) {
        JSONObject *leftObject = left.jsonObject;
        JSONObject *rightObject = right.jsonObject;
        if (leftObject.size != rightObject.size) {
            return NO;
        }
        for (NSString *key in leftObject.keys) {
            if (!OTSameValue([leftObject get:key], [rightObject get:key])) {
                return NO;
            }
        }
        return YES;
    }
    if (left.kind == JSONValueKindArray && right.kind == JSONValueKindArray) {
        JSONArray *leftArray = left.jsonArray;
        JSONArray *rightArray = right.jsonArray;
        if (leftArray.size != rightArray.size) {
            return NO;
        }
        for (NSInteger index = 0; index < leftArray.size; index++) {
            if (!OTSameValue([leftArray get:index], [rightArray get:index])) {
                return NO;
            }
        }
        return YES;
    }
    if (left.kind == JSONValueKindString && right.kind == JSONValueKindString) {
        return [left.string isEqualToString:right.string];
    }
    return NO;
}

static void OTCopyObject(JSONObject *target, JSONObject *source) {
    if (source == nil) {
        return;
    }
    for (NSString *key in source.keys) {
        [target set:[source get:key] ?: [JSONValue null] forKey:key];
    }
}

static JSONValue *OTCopyTree(JSONValue *value, PageParamsResolver resolver) {
    if (value == nil) {
        return nil;
    }
    switch (value.kind) {
        case JSONValueKindObject: {
            JSONObject *object = value.jsonObject;
            JSONObject *copy = [[JSONObject alloc] init];
            for (NSString *key in object.keys) {
                JSONValue *child = OTCopyTree([object get:key], resolver);
                [copy set:child ?: [JSONValue null] forKey:key];
            }
            return [JSONValue object:copy];
        }
        case JSONValueKindArray: {
            JSONArray *array = value.jsonArray;
            JSONArray *copy = [[JSONArray alloc] init];
            for (NSInteger index = 0; index < array.size; index++) {
                JSONValue *child = OTCopyTree([array get:index], resolver);
                [copy add:child ?: [JSONValue null]];
            }
            return [JSONValue array:copy];
        }
        case JSONValueKindString: {
            NSString *text = value.string;
            if ([text hasPrefix:@"$"]) {
                JSONValue *resolved = resolver != nil ? resolver(text) : nil;
                return resolved ?: value;
            }
            return value;
        }
        case JSONValueKindNumber:
        case JSONValueKindBool:
        case JSONValueKindNull:
            return value;
    }
    return value;
}

@implementation PageParams

+ (JSONObject *)evaluate:(JSONObject *)raw resolver:(PageParamsResolver)resolver {
    JSONValue *copied = OTCopyTree([JSONValue object:raw], resolver);
    if (copied.jsonObject == nil) {
        return [[JSONObject alloc] init];
    }
    return copied.jsonObject;
}

+ (BOOL)matches:(JSONObject *)data overlay:(JSONObject *)overlay {
    if (overlay == nil || overlay.isEmpty) {
        return YES;
    }
    if (data == nil) {
        return NO;
    }
    for (NSString *key in overlay.keys) {
        if (!OTSameValue([data get:key], [overlay get:key])) {
            return NO;
        }
    }
    return YES;
}

+ (void)mergeInto:(JSONObject *)target overlay:(JSONObject *)overlay {
    for (NSString *key in overlay.keys) {
        [target set:[overlay get:key] ?: [JSONValue null] forKey:key];
    }
}

+ (BOOL)findItemInPage:(JSONObject *)page
                  item:(JSONObject *)item
                   key:(NSString **)key
                 index:(NSInteger *)index {
    if (page == nil || item == nil) {
        return NO;
    }
    for (NSString *pageKey in page.keys) {
        JSONArray *array = [page get:pageKey].jsonArray;
        if (array == nil) {
            continue;
        }
        for (NSInteger cursor = 0; cursor < array.size; cursor++) {
            if ([array get:cursor].jsonObject == item) {
                if (key != NULL) {
                    *key = pageKey;
                }
                if (index != NULL) {
                    *index = cursor;
                }
                return YES;
            }
        }
    }
    return NO;
}

+ (JSONObject *)merge:(JSONObject *)base overlay:(JSONObject *)overlay {
    if (base == nil && overlay == nil) {
        return nil;
    }
    JSONObject *result = [[JSONObject alloc] init];
    OTCopyObject(result, base);
    OTCopyObject(result, overlay);
    return result;
}

@end
