#import "TemplateJsonParser.h"
#import "PageParams.h"
#import "TemplateKey.h"

#include <locale.h>
#include <stdlib.h>
#include <xlocale.h>

@implementation ParsedNode {
    NSString *_nodeId;
}

- (instancetype)initWithViewName:(NSString *)viewName
                              id:(NSString *)nodeId
                           attrs:(NSDictionary<NSString *, NSString *> *)attrs
                        children:(NSArray<ParsedNode *> *)children
                            item:(ParsedNode *)item {
    self = [super init];
    if (self != nil) {
        _viewName = [viewName copy];
        _nodeId = [nodeId copy];
        _attrs = [attrs copy] ?: @{};
        _children = [children copy] ?: @[];
        _item = item;
    }
    return self;
}

- (NSString *)id {
    return _nodeId;
}

@end

@implementation ParsedTemplate

- (instancetype)initWithRoot:(ParsedNode *)root events:(NSDictionary<NSString *, JSONObject *> *)events {
    self = [super init];
    if (self != nil) {
        _root = root;
        _events = [events copy];
    }
    return self;
}

@end

static BOOL OTFail(NSError **error, NSString *message) {
    if (error != NULL) {
        *error = TemplateParseExceptionError(message);
    }
    return NO;
}

static BOOL OTIsNull(JSONValue *value) {
    return value == nil || value.kind == JSONValueKindNull;
}

static NSString *OTStripTrailingZeros(NSString *text) {
    NSRange dot = [text rangeOfString:@"."];
    if (dot.location == NSNotFound) {
        return text;
    }
    NSUInteger end = text.length;
    while (end > dot.location) {
        if ([text characterAtIndex:end - 1] != '0') {
            break;
        }
        end -= 1;
    }
    if (end > dot.location && [text characterAtIndex:end - 1] == '.') {
        end -= 1;
    }
    if (end == 0) {
        return @"0";
    }
    NSString *result = [text substringToIndex:end];
    if (result.length == 0 || [result isEqualToString:@"-"]) {
        return @"0";
    }
    return result;
}

static NSDictionary<NSString *, NSString *> *OTJustifyValues(void) {
    static NSDictionary *values;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        values = @{
            @"start": @"start",
            @"center": @"center",
            @"end": @"end",
            @"spaceBetween": @"space-between",
            @"spaceAround": @"space-around",
            @"spaceEvenly": @"space-evenly"
        };
    });
    return values;
}

static NSDictionary<NSString *, NSString *> *OTAlignValues(void) {
    static NSDictionary *values;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        values = @{
            @"start": @"start",
            @"center": @"center",
            @"end": @"end",
            @"baseline": @"baseline",
            @"stretch": @"stretch"
        };
    });
    return values;
}

static NSDictionary<NSString *, NSString *> *OTGradientDirections(void) {
    static NSDictionary *values;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        values = @{
            @"bottom": @"to bottom",
            @"top": @"to top",
            @"left": @"to left",
            @"right": @"to right",
            @"topLeft": @"to top left",
            @"topRight": @"to top right",
            @"bottomLeft": @"to bottom left",
            @"bottomRight": @"to bottom right"
        };
    });
    return values;
}

static NSDictionary<NSString *, NSString *> *OTViewNames(void) {
    static NSDictionary *values;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        values = @{
            @"column": [TemplateKey COLUMN],
            @"row": [TemplateKey ROW],
            @"text": [TemplateKey TEXT],
            @"image": [TemplateKey IMAGE],
            @"spacer": [TemplateKey SPACER],
            @"list": [TemplateKey OT_LIST],
            @"progress": [TemplateKey PROGRESS],
            @"lottie": [TemplateKey ANIMATION],
            @"input": [TemplateKey INPUT],
            @"checkbox": [TemplateKey CHECKBOX],
            @"radio": [TemplateKey RADIO],
            @"switch": [TemplateKey SWITCH]
        };
    });
    return values;
}

static NSString *OTPlainNumber(JSONValue *value, NSString *path, NSError **error) {
    if (value.kind != JSONValueKindNumber || value.number == nil) {
        OTFail(error, [NSString stringWithFormat:@"%@ 必须是数字", path]);
        return nil;
    }
    JSONNumber *number = value.number;
    if (number.isDouble) {
        if (number.doubleValue < 0) {
            OTFail(error, [NSString stringWithFormat:@"%@ 不能是负数", path]);
            return nil;
        }
        if (number.doubleValue == 0) {
            return @"0";
        }
        return OTStripTrailingZeros(number.description);
    }
    if (number.intValue < 0) {
        OTFail(error, [NSString stringWithFormat:@"%@ 不能是负数", path]);
        return nil;
    }
    return [NSString stringWithFormat:@"%lld", (long long)number.intValue];
}

static NSString *OTBoolString(JSONValue *value, NSString *path, NSError **error) {
    if (value.kind != JSONValueKindBool) {
        OTFail(error, [NSString stringWithFormat:@"%@ 必须是布尔值", path]);
        return nil;
    }
    return value.boolValue ? @"true" : @"false";
}

static NSString *OTRequireName(JSONValue *value, NSString *path, NSError **error) {
    NSString *name = [JSONReader requireString:value path:path error:error];
    if (name == nil) {
        return nil;
    }
    if (![JSONText isName:name]) {
        OTFail(error, [NSString stringWithFormat:@"%@「%@」必须是字母或下划线开头的标识符", path, name]);
        return nil;
    }
    return name;
}

static NSString *OTCheckedValue(JSONValue *value, NSString *path, NSError **error) {
    if (value.kind == JSONValueKindBool) {
        return value.boolValue ? @"true" : @"false";
    }
    if (value.kind == JSONValueKindString && [value.string hasPrefix:@"$"]) {
        return value.string;
    }
    OTFail(error, [NSString stringWithFormat:@"%@ 必须是布尔值或以 $ 开头", path]);
    return nil;
}

static NSString *OTNonNegativeInt(JSONValue *value, NSString *path, NSError **error) {
    NSString *number = OTPlainNumber(value, path, error);
    if (number == nil) {
        return nil;
    }
    if ([number containsString:@"."]) {
        OTFail(error, [NSString stringWithFormat:@"%@ 只能是非负整数", path]);
        return nil;
    }
    return number;
}

static NSString *OTPositiveInt(JSONValue *value, NSString *path, NSError **error) {
    NSString *number = OTNonNegativeInt(value, path, error);
    if (number == nil) {
        return nil;
    }
    if ([number isEqualToString:@"0"]) {
        OTFail(error, [NSString stringWithFormat:@"%@ 必须是正整数", path]);
        return nil;
    }
    return number;
}

static NSString *OTPositiveNumber(JSONValue *value, NSString *path, NSError **error) {
    NSString *number = OTPlainNumber(value, path, error);
    if (number == nil) {
        return nil;
    }
    if ([number isEqualToString:@"0"]) {
        OTFail(error, [NSString stringWithFormat:@"%@ 必须是正数", path]);
        return nil;
    }
    return number;
}

static NSString *OTColorValue(JSONValue *value, NSString *path, NSError **error) {
    NSString *color = [JSONReader requireString:value path:path error:error];
    if (color == nil) {
        return nil;
    }
    if ([color isEqualToString:@"transparent"] || [color hasPrefix:@"$"] || [JSONText isHexColor:color]) {
        return color;
    }
    OTFail(error, [NSString stringWithFormat:@"%@ 必须是 #RGB、#RRGGBB、#AARRGGBB、transparent，或以 $ 开头", path]);
    return nil;
}

static NSString *OTEnumValue(JSONValue *value, NSString *path, NSDictionary<NSString *, NSString *> *mapping, NSError **error) {
    NSString *name = [JSONReader requireString:value path:path error:error];
    if (name == nil) {
        return nil;
    }
    NSString *mapped = mapping[name];
    if (mapped == nil) {
        OTFail(error, [NSString stringWithFormat:@"%@「%@」不在允许的取值里", path, name]);
        return nil;
    }
    return mapped;
}

static NSString *OTFlexValue(JSONValue *value, NSString *path, NSDictionary<NSString *, NSString *> *mapping, NSError **error) {
    NSString *name = [JSONReader requireString:value path:path error:error];
    if (name == nil) {
        return nil;
    }
    if ([name hasPrefix:@"$"]) {
        return name;
    }
    NSString *mapped = mapping[name];
    if (mapped == nil) {
        OTFail(error, [NSString stringWithFormat:@"%@「%@」不在允许的取值里", path, name]);
        return nil;
    }
    return mapped;
}

static NSString *OTSizeValue(JSONValue *value, NSString *path, NSError **error) {
    if (value.kind == JSONValueKindNumber) {
        return OTPlainNumber(value, path, error);
    }
    if (value.kind == JSONValueKindString) {
        NSString *text = value.string;
        if ([text isEqualToString:@"fill"]) {
            return [TemplateKey OT_MATCH_PARENT];
        }
        if ([text isEqualToString:@"wrap"]) {
            return [TemplateKey OT_WRAP_CONTENT];
        }
    }
    OTFail(error, [NSString stringWithFormat:@"%@ 只能是数字、fill 或 wrap", path]);
    return nil;
}

static BOOL OTSwiftDoubleParses(NSString *text) {
    if (text.length == 0) {
        return NO;
    }
    unichar first = [text characterAtIndex:0];
    if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:first]) {
        return NO;
    }
    const char *utf8 = text.UTF8String;
    if (utf8 == NULL) {
        return NO;
    }
    locale_t locale = newlocale(LC_NUMERIC_MASK, "C", NULL);
    locale_t previous = uselocale(locale);
    char *end = NULL;
    strtod(utf8, &end);
    uselocale(previous);
    freelocale(locale);
    return end != utf8 && end != NULL && *end == '\0';
}

static NSString *OTFractionValue(JSONValue *value, NSString *path, NSError **error) {
    if (value.kind == JSONValueKindNumber) {
        return OTPlainNumber(value, path, error);
    }
    if (value.kind == JSONValueKindString) {
        NSString *text = value.string;
        if ([text hasPrefix:@"$"] || OTSwiftDoubleParses(text)) {
            return text;
        }
    }
    OTFail(error, [NSString stringWithFormat:@"%@ 必须是数字或以 $ 开头", path]);
    return nil;
}

static NSString *OTRepeatValue(JSONValue *value, NSString *path, NSError **error) {
    if (value.kind == JSONValueKindString) {
        if ([value.string isEqualToString:@"infinite"]) {
            return value.string;
        }
        OTFail(error, [NSString stringWithFormat:@"%@ 只能是 infinite 或非负整数", path]);
        return nil;
    }
    if (value.kind == JSONValueKindNumber) {
        NSString *number = OTPlainNumber(value, path, error);
        if (number == nil) {
            return nil;
        }
        if ([number containsString:@"."]) {
            OTFail(error, [NSString stringWithFormat:@"%@ 只能是 infinite 或非负整数", path]);
            return nil;
        }
        return number;
    }
    OTFail(error, [NSString stringWithFormat:@"%@ 只能是 infinite 或非负整数", path]);
    return nil;
}

static NSString *OTGroupValue(JSONValue *value, NSString *path, NSError **error) {
    NSString *name = [JSONReader requireString:value path:path error:error];
    if (name == nil) {
        return nil;
    }
    if ([name hasPrefix:@"$"] || [JSONText isName:name]) {
        return name;
    }
    OTFail(error, [NSString stringWithFormat:@"%@「%@」必须是字母或下划线开头的标识符，或以 $ 开头", path, name]);
    return nil;
}

static NSString *OTIndexValue(JSONValue *value, NSString *path, NSError **error) {
    if (value.kind == JSONValueKindString) {
        if ([value.string hasPrefix:@"$"]) {
            return value.string;
        }
        OTFail(error, [NSString stringWithFormat:@"%@ 必须是非负整数或以 $ 开头", path]);
        return nil;
    }
    if (value.kind == JSONValueKindNumber) {
        return OTNonNegativeInt(value, path, error);
    }
    OTFail(error, [NSString stringWithFormat:@"%@ 必须是非负整数或以 $ 开头", path]);
    return nil;
}

static NSString *OTBackgroundValue(JSONValue *value, NSString *path, NSError **error);
static NSString *OTSolidColor(JSONValue *value, NSString *path, NSError **error);

static NSString *OTSolidColor(JSONValue *value, NSString *path, NSError **error) {
    if (value.kind == JSONValueKindObject) {
        OTFail(error, [NSString stringWithFormat:@"%@ 必须是颜色，不能是渐变", path]);
        return nil;
    }
    return OTColorValue(value, path, error);
}

static NSString *OTBackgroundValue(JSONValue *value, NSString *path, NSError **error) {
    if (value.kind == JSONValueKindString) {
        NSString *text = value.string;
        if ([text hasPrefix:@"res:"]) {
            NSString *name = [text substringFromIndex:[@"res:" length]];
            if (![JSONText isName:name]) {
                OTFail(error, [NSString stringWithFormat:@"%@ 的资源名必须是字母或下划线开头", path]);
                return nil;
            }
            return text;
        }
        return OTColorValue(value, path, error);
    }
    if (value.kind == JSONValueKindObject) {
        JSONObject *object = value.jsonObject;
        if (![JSONReader requireKeys:object
                                path:path
                             allowed:[NSSet setWithObjects:@"direction", @"colors", nil]
                            required:@[@"direction", @"colors"]
                               error:error]) {
            return nil;
        }
        NSString *direction = OTEnumValue([object get:@"direction"],
                                          [path stringByAppendingString:@".direction"],
                                          OTGradientDirections(),
                                          error);
        if (direction == nil) {
            return nil;
        }
        JSONArray *colors = [JSONReader requireArray:[object get:@"colors"]
                                                path:[path stringByAppendingString:@".colors"]
                                               error:error];
        if (colors == nil) {
            return nil;
        }
        if (colors.size < 2) {
            OTFail(error, [NSString stringWithFormat:@"%@.colors 至少要有两个颜色", path]);
            return nil;
        }
        NSMutableArray<NSString *> *colorList = [NSMutableArray array];
        for (NSInteger index = 0; index < colors.size; index++) {
            NSString *color = OTColorValue([colors get:index],
                                           [NSString stringWithFormat:@"%@.colors[%ld]", path, (long)index],
                                           error);
            if (color == nil) {
                return nil;
            }
            [colorList addObject:color];
        }
        return [NSString stringWithFormat:@"linear-gradient(%@, %@)", direction, [colorList componentsJoinedByString:@", "]];
    }
    OTFail(error, [NSString stringWithFormat:@"%@ 必须是颜色或渐变对象", path]);
    return nil;
}

static NSString *OTPaintValue(JSONValue *value, NSString *path, NSError **error) {
    if (value.kind == JSONValueKindObject) {
        return OTBackgroundValue(value, path, error);
    }
    return OTColorValue(value, path, error);
}

static NSArray<NSString *> *OTTargetList(JSONValue *value, NSString *path, NSError **error) {
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    if (value.kind == JSONValueKindArray) {
        JSONArray *array = value.jsonArray;
        for (NSInteger index = 0; index < array.size; index++) {
            NSString *name = OTRequireName([array get:index],
                                           [NSString stringWithFormat:@"%@[%ld]", path, (long)index],
                                           error);
            if (name == nil) {
                return nil;
            }
            [names addObject:name];
        }
    } else {
        NSString *name = OTRequireName(value, path, error);
        if (name == nil) {
            return nil;
        }
        [names addObject:name];
    }
    if (names.count == 0) {
        OTFail(error, [NSString stringWithFormat:@"%@ 不能是空数组", path]);
        return nil;
    }
    return names;
}

static NSArray<NSString *> *OTParseNames(JSONValue *value, NSString *path, NSError **error) {
    JSONArray *array = [JSONReader requireArray:value path:path error:error];
    if (array == nil) {
        return nil;
    }
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSInteger index = 0; index < array.size; index++) {
        NSString *name = OTRequireName([array get:index],
                                       [NSString stringWithFormat:@"%@[%ld]", path, (long)index],
                                       error);
        if (name == nil) {
            return nil;
        }
        [names addObject:name];
    }
    return names;
}

static JSONValue *OTParseParamValue(JSONValue *value, NSString *path, NSError **error);

static JSONObject *OTParseOpenParams(JSONValue *value, NSString *path, NSError **error) {
    if (value.kind != JSONValueKindObject || value.jsonObject == nil) {
        OTFail(error, [NSString stringWithFormat:@"%@ 必须是对象", path]);
        return nil;
    }
    JSONObject *params = value.jsonObject;
    JSONObject *result = [[JSONObject alloc] init];
    for (NSString *key in params.keys) {
        if (![JSONText isName:key]) {
            OTFail(error, [NSString stringWithFormat:@"%@.%@ 不是这里能写的字段", path, key]);
            return nil;
        }
        JSONValue *parsed = OTParseParamValue([params get:key],
                                              [NSString stringWithFormat:@"%@.%@", path, key],
                                              error);
        if (parsed == nil) {
            return nil;
        }
        [result set:parsed forKey:key];
    }
    return result;
}

static JSONValue *OTParseParamValue(JSONValue *value, NSString *path, NSError **error) {
    if (value.kind == JSONValueKindString || value.kind == JSONValueKindNumber || value.kind == JSONValueKindBool) {
        return value;
    }
    if (value.kind == JSONValueKindObject) {
        JSONObject *object = OTParseOpenParams(value, path, error);
        if (object == nil) {
            return nil;
        }
        return [JSONValue object:object];
    }
    if (value.kind == JSONValueKindArray) {
        JSONArray *array = value.jsonArray;
        JSONArray *copy = [[JSONArray alloc] init];
        for (NSInteger index = 0; index < array.size; index++) {
            JSONValue *parsed = OTParseParamValue([array get:index],
                                                  [NSString stringWithFormat:@"%@[%ld]", path, (long)index],
                                                  error);
            if (parsed == nil) {
                return nil;
            }
            [copy add:parsed];
        }
        return [JSONValue array:copy];
    }
    OTFail(error, [NSString stringWithFormat:@"%@ 必须是字符串、数字、布尔、对象或数组", path]);
    return nil;
}

static JSONObject *OTViewEvent(NSString *key, NSString *target, JSONValue *value) {
    JSONObject *params = [[JSONObject alloc] init];
    [params set:[JSONValue string:@"changeAttributes"] forKey:@"fun"];
    [params set:[JSONValue string:key] forKey:@"key"];
    [params set:[JSONValue string:target] forKey:@"id"];
    [params set:value forKey:@"value"];
    JSONObject *event = [[JSONObject alloc] init];
    [event set:[JSONValue string:@"view"] forKey:@"class"];
    [event set:[JSONValue object:params] forKey:@"params"];
    return event;
}

static JSONObject *OTParseStringMap(JSONValue *value, NSString *path, NSError **error) {
    JSONObject *item = [JSONReader requireObject:value path:path error:error];
    if (item == nil) {
        return nil;
    }
    JSONObject *fields = [[JSONObject alloc] init];
    for (NSString *key in item.keys) {
        if (![JSONText isName:key]) {
            OTFail(error, [NSString stringWithFormat:@"%@.%@ 不是这里能写的字段", path, key]);
            return nil;
        }
        NSString *text = [JSONReader requireString:[item get:key]
                                              path:[NSString stringWithFormat:@"%@.%@", path, key]
                                             error:error];
        if (text == nil) {
            return nil;
        }
        [fields set:[JSONValue string:text] forKey:key];
    }
    return fields;
}

static JSONObject *OTParseAppendEvent(JSONObject *event, NSString *path, NSError **error) {
    if (![JSONReader requireKeys:event
                            path:path
                         allowed:[NSSet setWithObjects:@"action", @"list", @"from", @"field", @"data", @"item", @"empty", nil]
                        required:@[@"action", @"list", @"from", @"field", @"data", @"item"]
                           error:error]) {
        return nil;
    }
    NSString *list = OTRequireName([event get:@"list"], [path stringByAppendingString:@".list"], error);
    NSString *from = OTRequireName([event get:@"from"], [path stringByAppendingString:@".from"], error);
    NSString *field = OTRequireName([event get:@"field"], [path stringByAppendingString:@".field"], error);
    NSString *data = OTRequireName([event get:@"data"], [path stringByAppendingString:@".data"], error);
    JSONObject *item = OTParseStringMap([event get:@"item"], [path stringByAppendingString:@".item"], error);
    if (list == nil || from == nil || field == nil || data == nil || item == nil) {
        return nil;
    }
    JSONObject *params = [[JSONObject alloc] init];
    [params set:[JSONValue string:@"append"] forKey:@"fun"];
    [params set:[JSONValue string:list] forKey:@"id"];
    [params set:[JSONValue string:from] forKey:@"from"];
    [params set:[JSONValue string:field] forKey:@"field"];
    [params set:[JSONValue string:data] forKey:@"data"];
    [params set:[JSONValue object:item] forKey:@"item"];
    if ([event containsKey:@"empty"]) {
        NSString *empty = [JSONReader requireString:[event get:@"empty"]
                                               path:[path stringByAppendingString:@".empty"]
                                              error:error];
        if (empty == nil) {
            return nil;
        }
        [params set:[JSONValue string:empty] forKey:@"empty"];
    }
    JSONObject *result = [[JSONObject alloc] init];
    [result set:[JSONValue string:@"list"] forKey:@"class"];
    [result set:[JSONValue object:params] forKey:@"params"];
    return result;
}

static JSONObject *OTParseUpdateEvent(JSONObject *event, NSString *path, NSError **error) {
    if (![JSONReader requireKeys:event
                            path:path
                         allowed:[NSSet setWithObjects:@"action", @"list", @"index", @"item", nil]
                        required:@[@"action", @"list", @"index", @"item"]
                           error:error]) {
        return nil;
    }
    NSString *list = OTRequireName([event get:@"list"], [path stringByAppendingString:@".list"], error);
    NSString *index = OTIndexValue([event get:@"index"], [path stringByAppendingString:@".index"], error);
    JSONObject *item = OTParseStringMap([event get:@"item"], [path stringByAppendingString:@".item"], error);
    if (list == nil || index == nil || item == nil) {
        return nil;
    }
    JSONObject *params = [[JSONObject alloc] init];
    [params set:[JSONValue string:@"update"] forKey:@"fun"];
    [params set:[JSONValue string:list] forKey:@"id"];
    [params set:[JSONValue string:index] forKey:@"index"];
    [params set:[JSONValue object:item] forKey:@"item"];
    JSONObject *result = [[JSONObject alloc] init];
    [result set:[JSONValue string:@"list"] forKey:@"class"];
    [result set:[JSONValue object:params] forKey:@"params"];
    return result;
}

static JSONObject *OTParseRemoveEvent(JSONObject *event, NSString *path, NSError **error) {
    if (![JSONReader requireKeys:event
                            path:path
                         allowed:[NSSet setWithObjects:@"action", @"list", @"index", nil]
                        required:@[@"action", @"list", @"index"]
                           error:error]) {
        return nil;
    }
    NSString *list = OTRequireName([event get:@"list"], [path stringByAppendingString:@".list"], error);
    NSString *index = OTIndexValue([event get:@"index"], [path stringByAppendingString:@".index"], error);
    if (list == nil || index == nil) {
        return nil;
    }
    JSONObject *params = [[JSONObject alloc] init];
    [params set:[JSONValue string:@"remove"] forKey:@"fun"];
    [params set:[JSONValue string:list] forKey:@"id"];
    [params set:[JSONValue string:index] forKey:@"index"];
    JSONObject *result = [[JSONObject alloc] init];
    [result set:[JSONValue string:@"list"] forKey:@"class"];
    [result set:[JSONValue object:params] forKey:@"params"];
    return result;
}

static JSONObject *OTParsePageEvent(JSONObject *event, NSString *path, NSString *funName, NSError **error) {
    if (![JSONReader requireKeys:event
                            path:path
                         allowed:[NSSet setWithObjects:@"action", @"page", @"params", nil]
                        required:@[@"action", @"page"]
                           error:error]) {
        return nil;
    }
    NSString *page = [JSONReader requireString:[event get:@"page"] path:[path stringByAppendingString:@".page"] error:error];
    if (page == nil) {
        return nil;
    }
    if (![page hasPrefix:@"$"] && ![JSONText isName:page]) {
        OTFail(error, [NSString stringWithFormat:@"%@.page 必须是页面名或以 $ 开头", path]);
        return nil;
    }
    JSONObject *params = [[JSONObject alloc] init];
    [params set:[JSONValue string:funName] forKey:@"fun"];
    [params set:[JSONValue string:page] forKey:@"page"];
    if ([event containsKey:@"params"]) {
        JSONObject *inner = OTParseOpenParams([event get:@"params"], [path stringByAppendingString:@".params"], error);
        if (inner == nil) {
            return nil;
        }
        [params set:[JSONValue object:inner] forKey:@"params"];
    }
    JSONObject *result = [[JSONObject alloc] init];
    [result set:[JSONValue string:@"nav"] forKey:@"class"];
    [result set:[JSONValue object:params] forKey:@"params"];
    return result;
}

static JSONObject *OTParseHostEvent(JSONObject *event, NSString *path, NSError **error) {
    if (![JSONReader requireKeys:event
                            path:path
                         allowed:[NSSet setWithObjects:@"action", @"name", @"params", nil]
                        required:@[@"action", @"name"]
                           error:error]) {
        return nil;
    }
    NSString *hostName = [JSONReader requireString:[event get:@"name"] path:[path stringByAppendingString:@".name"] error:error];
    if (hostName == nil) {
        return nil;
    }
    if (![hostName hasPrefix:@"$"] && ![JSONText isName:hostName]) {
        OTFail(error, [NSString stringWithFormat:@"%@.name 必须是标识符或以 $ 开头", path]);
        return nil;
    }
    JSONObject *params = [[JSONObject alloc] init];
    [params set:[JSONValue string:@"host"] forKey:@"fun"];
    [params set:[JSONValue string:hostName] forKey:@"name"];
    if ([event containsKey:@"params"]) {
        JSONObject *inner = OTParseOpenParams([event get:@"params"], [path stringByAppendingString:@".params"], error);
        if (inner == nil) {
            return nil;
        }
        [params set:[JSONValue object:inner] forKey:@"params"];
    }
    JSONObject *result = [[JSONObject alloc] init];
    [result set:[JSONValue string:@"nav"] forKey:@"class"];
    [result set:[JSONValue object:params] forKey:@"params"];
    return result;
}

static JSONObject *OTParseEvent(NSString *name, JSONObject *event, NSString *path, NSError **error) {
    if ([event get:@"action"].kind != JSONValueKindString) {
        OTFail(error, [NSString stringWithFormat:@"%@ 缺少 action", path]);
        return nil;
    }
    NSString *action = [event get:@"action"].string;
    if ([action isEqualToString:@"toast"]) {
        if (![JSONReader requireKeys:event
                                path:path
                             allowed:[NSSet setWithObjects:@"action", @"message", nil]
                            required:@[@"action", @"message"]
                               error:error]) {
            return nil;
        }
        NSString *message = [JSONReader requireString:[event get:@"message"]
                                                path:[path stringByAppendingString:@".message"]
                                               error:error];
        if (message == nil) {
            return nil;
        }
        JSONObject *params = [[JSONObject alloc] init];
        [params set:[JSONValue string:@"showToast"] forKey:@"fun"];
        [params set:[JSONValue string:message] forKey:@"info"];
        JSONObject *result = [[JSONObject alloc] init];
        [result set:[JSONValue string:@"util"] forKey:@"class"];
        [result set:[JSONValue object:params] forKey:@"params"];
        return result;
    }
    if ([action isEqualToString:@"setText"]) {
        if (![JSONReader requireKeys:event
                                path:path
                             allowed:[NSSet setWithObjects:@"action", @"target", @"value", nil]
                            required:@[@"action", @"target", @"value"]
                               error:error]) {
            return nil;
        }
        NSString *target = OTRequireName([event get:@"target"], [path stringByAppendingString:@".target"], error);
        NSString *text = [JSONReader requireString:[event get:@"value"]
                                              path:[path stringByAppendingString:@".value"]
                                             error:error];
        if (target == nil || text == nil) {
            return nil;
        }
        return OTViewEvent(@"setText", target, [JSONValue string:text]);
    }
    if ([action isEqualToString:@"setTextStyle"]) {
        if (![JSONReader requireKeys:event
                                path:path
                             allowed:[NSSet setWithObjects:@"action", @"target", @"fontSize", @"color", @"text", nil]
                            required:@[@"action", @"target"]
                               error:error]) {
            return nil;
        }
        JSONObject *style = [[JSONObject alloc] init];
        if ([event containsKey:@"fontSize"]) {
            NSString *fontSize = OTPlainNumber([event get:@"fontSize"], [path stringByAppendingString:@".fontSize"], error);
            if (fontSize == nil) {
                return nil;
            }
            [style set:[JSONValue string:fontSize] forKey:[TemplateKey ATTR_TEXT_SIZE]];
        }
        if ([event containsKey:@"color"]) {
            NSString *color = OTColorValue([event get:@"color"], [path stringByAppendingString:@".color"], error);
            if (color == nil) {
                return nil;
            }
            [style set:[JSONValue string:color] forKey:[TemplateKey ATTR_TEXT_COLOR]];
        }
        if ([event containsKey:@"text"]) {
            NSString *text = [JSONReader requireString:[event get:@"text"]
                                                  path:[path stringByAppendingString:@".text"]
                                                 error:error];
            if (text == nil) {
                return nil;
            }
            [style set:[JSONValue string:text] forKey:[TemplateKey ATTR_TEXT]];
        }
        if (style.isEmpty) {
            OTFail(error, [NSString stringWithFormat:@"%@ 至少要写 fontSize、color、text 中的一个", path]);
            return nil;
        }
        NSString *target = OTRequireName([event get:@"target"], [path stringByAppendingString:@".target"], error);
        if (target == nil) {
            return nil;
        }
        JSONArray *attributes = [[JSONArray alloc] init];
        [attributes add:[JSONValue object:style]];
        JSONObject *value = [[JSONObject alloc] init];
        [value set:[JSONValue array:attributes] forKey:@"attributes"];
        return OTViewEvent(@"setTextStyle", target, [JSONValue object:value]);
    }
    if ([action isEqualToString:@"setChecked"]) {
        if (![JSONReader requireKeys:event
                                path:path
                             allowed:[NSSet setWithObjects:@"action", @"target", @"value", nil]
                            required:@[@"action", @"target", @"value"]
                               error:error]) {
            return nil;
        }
        NSArray<NSString *> *targets = OTTargetList([event get:@"target"], [path stringByAppendingString:@".target"], error);
        NSString *checked = OTCheckedValue([event get:@"value"], [path stringByAppendingString:@".value"], error);
        if (targets == nil || checked == nil) {
            return nil;
        }
        return OTViewEvent(@"setChecked", [targets componentsJoinedByString:@","], [JSONValue string:checked]);
    }
    if ([action isEqualToString:@"append"]) {
        return OTParseAppendEvent(event, path, error);
    }
    if ([action isEqualToString:@"update"]) {
        return OTParseUpdateEvent(event, path, error);
    }
    if ([action isEqualToString:@"remove"]) {
        return OTParseRemoveEvent(event, path, error);
    }
    if ([action isEqualToString:@"open"]) {
        return OTParsePageEvent(event, path, @"open", error);
    }
    if ([action isEqualToString:@"replace"]) {
        return OTParsePageEvent(event, path, @"replace", error);
    }
    if ([action isEqualToString:@"popTo"]) {
        return OTParsePageEvent(event, path, @"popTo", error);
    }
    if ([action isEqualToString:@"host"]) {
        return OTParseHostEvent(event, path, error);
    }
    if ([action isEqualToString:@"back"]) {
        if (![JSONReader requireKeys:event
                                path:path
                             allowed:[NSSet setWithObjects:@"action", @"params", nil]
                            required:@[@"action"]
                               error:error]) {
            return nil;
        }
        JSONObject *params = [[JSONObject alloc] init];
        [params set:[JSONValue string:@"back"] forKey:@"fun"];
        if ([event containsKey:@"params"]) {
            JSONObject *inner = OTParseOpenParams([event get:@"params"], [path stringByAppendingString:@".params"], error);
            if (inner == nil) {
                return nil;
            }
            [params set:[JSONValue object:inner] forKey:@"params"];
        }
        JSONObject *result = [[JSONObject alloc] init];
        [result set:[JSONValue string:@"nav"] forKey:@"class"];
        [result set:[JSONValue object:params] forKey:@"params"];
        return result;
    }
    OTFail(error, [NSString stringWithFormat:@"%@.action「%@」无法识别，事件 %@ 只能是 toast、setText、setTextStyle、setChecked、append、update、remove、open、back、replace、popTo、host", path, action, name]);
    return nil;
}

static BOOL OTParseEvents(JSONValue *value,
                          NSString *path,
                          NSMutableArray<NSString *> *names,
                          NSMutableArray<JSONObject *> *events,
                          NSError **error) {
    if (OTIsNull(value)) {
        return YES;
    }
    JSONObject *object = [JSONReader requireObject:value path:path error:error];
    if (object == nil) {
        return NO;
    }
    for (NSString *name in object.keys) {
        if (![JSONText isName:name]) {
            return OTFail(error, [NSString stringWithFormat:@"%@ 的事件名「%@」必须是字母或下划线开头的标识符", path, name]);
        }
        NSString *eventPath = [NSString stringWithFormat:@"%@.%@", path, name];
        JSONObject *event = [JSONReader requireObject:[object get:name] path:eventPath error:error];
        if (event == nil) {
            return NO;
        }
        JSONObject *parsed = OTParseEvent(name, event, eventPath, error);
        if (parsed == nil) {
            return NO;
        }
        [names addObject:name];
        [events addObject:parsed];
    }
    return YES;
}

static BOOL OTPutSide(JSONObject *source,
                      NSString *key,
                      NSString *attrName,
                      NSString *path,
                      NSMutableDictionary<NSString *, NSString *> *attrs,
                      NSError **error) {
    if (![source containsKey:key]) {
        return YES;
    }
    NSString *number = OTPlainNumber([source get:key], [NSString stringWithFormat:@"%@.%@", path, key], error);
    if (number == nil) {
        return NO;
    }
    attrs[attrName] = number;
    return YES;
}

static BOOL OTParseEdges(JSONValue *value,
                         NSString *path,
                         NSString *uniform,
                         NSString *start,
                         NSString *end,
                         NSString *top,
                         NSString *bottom,
                         NSMutableDictionary<NSString *, NSString *> *attrs,
                         NSError **error) {
    if (value.kind == JSONValueKindNumber) {
        NSString *number = OTPlainNumber(value, path, error);
        if (number == nil) {
            return NO;
        }
        attrs[uniform] = number;
        return YES;
    }
    if (value.kind == JSONValueKindObject) {
        JSONObject *object = value.jsonObject;
        if (![JSONReader requireKeys:object
                                path:path
                             allowed:[NSSet setWithObjects:@"start", @"end", @"top", @"bottom", nil]
                            required:@[]
                               error:error]) {
            return NO;
        }
        if (object.isEmpty) {
            return OTFail(error, [NSString stringWithFormat:@"%@ 不能是空对象", path]);
        }
        return OTPutSide(object, @"start", start, path, attrs, error) &&
            OTPutSide(object, @"end", end, path, attrs, error) &&
            OTPutSide(object, @"top", top, path, attrs, error) &&
            OTPutSide(object, @"bottom", bottom, path, attrs, error);
    }
    return OTFail(error, [NSString stringWithFormat:@"%@ 必须是数字或四边对象", path]);
}

static BOOL OTPutSize(JSONObject *layout,
                      NSString *key,
                      NSString *attrName,
                      NSString *path,
                      NSMutableDictionary<NSString *, NSString *> *attrs,
                      NSError **error) {
    if (![layout containsKey:key]) {
        return YES;
    }
    NSString *size = OTSizeValue([layout get:key], [NSString stringWithFormat:@"%@.%@", path, key], error);
    if (size == nil) {
        return NO;
    }
    attrs[attrName] = size;
    return YES;
}

static BOOL OTParseLayout(JSONObject *layout,
                          NSString *path,
                          BOOL isContainer,
                          NSMutableDictionary<NSString *, NSString *> *attrs,
                          NSError **error) {
    NSMutableSet<NSString *> *allowed = [NSMutableSet setWithArray:@[
        @"width", @"height", @"padding", @"grow", @"margin",
        @"minWidth", @"minHeight", @"maxWidth", @"maxHeight", @"aspectRatio", @"alignSelf"
    ]];
    if (isContainer) {
        [allowed addObject:@"justify"];
        [allowed addObject:@"align"];
        [allowed addObject:@"wrap"];
    }
    if (![JSONReader requireKeys:layout path:path allowed:allowed required:@[@"width", @"height"] error:error]) {
        return NO;
    }
    NSString *width = OTSizeValue([layout get:@"width"], [path stringByAppendingString:@".width"], error);
    NSString *height = OTSizeValue([layout get:@"height"], [path stringByAppendingString:@".height"], error);
    if (width == nil || height == nil) {
        return NO;
    }
    attrs[[TemplateKey ATTR_WIDTH]] = width;
    attrs[[TemplateKey ATTR_HEIGHT]] = height;
    if ([layout containsKey:@"padding"]) {
        if (!OTParseEdges([layout get:@"padding"],
                          [path stringByAppendingString:@".padding"],
                          [TemplateKey ATTR_PADDING],
                          [TemplateKey ATTR_PADDING_START],
                          [TemplateKey ATTR_PADDING_END],
                          [TemplateKey ATTR_PADDING_TOP],
                          [TemplateKey ATTR_PADDING_BOTTOM],
                          attrs,
                          error)) {
            return NO;
        }
    }
    if ([layout containsKey:@"margin"]) {
        if (!OTParseEdges([layout get:@"margin"],
                          [path stringByAppendingString:@".margin"],
                          [TemplateKey ATTR_MARGIN],
                          [TemplateKey ATTR_MARGIN_START],
                          [TemplateKey ATTR_MARGIN_END],
                          [TemplateKey ATTR_MARGIN_TOP],
                          [TemplateKey ATTR_MARGIN_BOTTOM],
                          attrs,
                          error)) {
            return NO;
        }
    }
    if (!OTPutSize(layout, @"minWidth", [TemplateKey ATTR_MIN_WIDTH], path, attrs, error) ||
        !OTPutSize(layout, @"minHeight", [TemplateKey ATTR_MIN_HEIGHT], path, attrs, error) ||
        !OTPutSize(layout, @"maxWidth", [TemplateKey ATTR_MAX_WIDTH], path, attrs, error) ||
        !OTPutSize(layout, @"maxHeight", [TemplateKey ATTR_MAX_HEIGHT], path, attrs, error)) {
        return NO;
    }
    if ([layout containsKey:@"aspectRatio"]) {
        NSString *ratio = OTPositiveNumber([layout get:@"aspectRatio"], [path stringByAppendingString:@".aspectRatio"], error);
        if (ratio == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_ASPECT_RATIO]] = ratio;
    }
    if ([layout containsKey:@"alignSelf"]) {
        NSString *alignSelf = [JSONReader requireString:[layout get:@"alignSelf"]
                                                   path:[path stringByAppendingString:@".alignSelf"]
                                                  error:error];
        if (alignSelf == nil) {
            return NO;
        }
        NSSet *alignSelfValues = [NSSet setWithObjects:@"start", @"center", @"end", @"stretch", nil];
        if (![alignSelfValues containsObject:alignSelf]) {
            return OTFail(error, [NSString stringWithFormat:@"%@.alignSelf 只能是 start、center、end、stretch", path]);
        }
        attrs[[TemplateKey ATTR_ALIGN_SELF]] = alignSelf;
    }
    if ([layout containsKey:@"grow"]) {
        NSString *grow = OTPlainNumber([layout get:@"grow"], [path stringByAppendingString:@".grow"], error);
        if (grow == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_FLEX_GROW]] = grow;
    }
    if ([layout containsKey:@"wrap"]) {
        NSString *wrap = OTBoolString([layout get:@"wrap"], [path stringByAppendingString:@".wrap"], error);
        if (wrap == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_FLEX_WRAP]] = [wrap isEqualToString:@"true"] ? @"wrap" : @"nowrap";
    }
    if ([layout containsKey:@"justify"]) {
        NSString *justify = OTFlexValue([layout get:@"justify"], [path stringByAppendingString:@".justify"], OTJustifyValues(), error);
        if (justify == nil) {
            return NO;
        }
        attrs[[TemplateKey FLEXBOX_ATTR_JUSTIFY_CONTENT]] = justify;
    }
    if ([layout containsKey:@"align"]) {
        NSString *align = OTEnumValue([layout get:@"align"], [path stringByAppendingString:@".align"], OTAlignValues(), error);
        if (align == nil) {
            return NO;
        }
        attrs[[TemplateKey FLEXBOX_ATTR_ALIGN_ITEMS]] = align;
    }
    return YES;
}

static BOOL OTParseRadius(JSONValue *value, NSString *path, NSMutableDictionary<NSString *, NSString *> *attrs, NSError **error) {
    if (value.kind == JSONValueKindNumber) {
        NSString *number = OTPlainNumber(value, path, error);
        if (number == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_RADIUS]] = number;
        return YES;
    }
    if (value.kind == JSONValueKindObject) {
        JSONObject *object = value.jsonObject;
        if (![JSONReader requireKeys:object
                                path:path
                             allowed:[NSSet setWithObjects:@"topStart", @"topEnd", @"bottomEnd", @"bottomStart", nil]
                            required:@[]
                               error:error]) {
            return NO;
        }
        if (object.isEmpty) {
            return OTFail(error, [NSString stringWithFormat:@"%@ 不能是空对象", path]);
        }
        return OTPutSide(object, @"topStart", [TemplateKey ATTR_LEFT_TOP_RADIUS], path, attrs, error) &&
            OTPutSide(object, @"topEnd", [TemplateKey ATTR_RIGHT_TOP_RADIUS], path, attrs, error) &&
            OTPutSide(object, @"bottomEnd", [TemplateKey ATTR_RIGHT_BOTTOM_RADIUS], path, attrs, error) &&
            OTPutSide(object, @"bottomStart", [TemplateKey ATTR_LEFT_BOTTOM_RADIUS], path, attrs, error);
    }
    return OTFail(error, [NSString stringWithFormat:@"%@ 必须是数字或四角对象", path]);
}

static BOOL OTParseGlass(JSONObject *glass, NSString *path, NSMutableDictionary<NSString *, NSString *> *attrs, NSError **error) {
    if (![JSONReader requireKeys:glass
                            path:path
                         allowed:[NSSet setWithObjects:@"style", @"tint", @"interactive", nil]
                        required:@[]
                           error:error]) {
        return NO;
    }
    NSString *style = @"regular";
    if ([glass containsKey:@"style"]) {
        style = [JSONReader requireString:[glass get:@"style"] path:[path stringByAppendingString:@".style"] error:error];
        if (style == nil) {
            return NO;
        }
    }
    if (![style isEqualToString:@"regular"] && ![style isEqualToString:@"clear"]) {
        return OTFail(error, [NSString stringWithFormat:@"%@.style 只能是 regular、clear", path]);
    }
    attrs[[TemplateKey ATTR_GLASS_STYLE]] = style;
    if ([glass containsKey:@"tint"]) {
        NSString *tint = OTSolidColor([glass get:@"tint"], [path stringByAppendingString:@".tint"], error);
        if (tint == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_GLASS_TINT]] = tint;
    }
    if ([glass containsKey:@"interactive"]) {
        NSString *interactive = OTBoolString([glass get:@"interactive"], [path stringByAppendingString:@".interactive"], error);
        if (interactive == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_GLASS_INTERACTIVE]] = interactive;
    }
    return YES;
}

static BOOL OTParseBorder(JSONObject *border, NSString *path, NSMutableDictionary<NSString *, NSString *> *attrs, NSError **error) {
    if (![JSONReader requireKeys:border
                            path:path
                         allowed:[NSSet setWithObjects:@"color", @"width", nil]
                        required:@[@"color", @"width"]
                           error:error]) {
        return NO;
    }
    NSString *color = OTColorValue([border get:@"color"], [path stringByAppendingString:@".color"], error);
    NSString *width = OTPlainNumber([border get:@"width"], [path stringByAppendingString:@".width"], error);
    if (color == nil || width == nil) {
        return NO;
    }
    attrs[[TemplateKey ATTR_BORDER_COLOR]] = color;
    attrs[[TemplateKey ATTR_BORDER_WIDTH]] = width;
    return YES;
}

static BOOL OTParseStyle(JSONObject *style,
                         NSString *path,
                         NSString *type,
                         NSMutableDictionary<NSString *, NSString *> *attrs,
                         NSError **error) {
    NSMutableSet<NSString *> *allowed = [NSMutableSet setWithArray:@[@"background", @"radius", @"border"]];
    if ([type isEqualToString:@"column"] || [type isEqualToString:@"row"] || [type isEqualToString:@"spacer"]) {
        [allowed addObject:@"glass"];
    }
    if ([type isEqualToString:@"text"]) {
        [allowed addObjectsFromArray:@[@"color", @"fontSize", @"align", @"maxLines", @"ellipsis", @"fontWeight"]];
    } else if ([type isEqualToString:@"image"]) {
        [allowed addObjectsFromArray:@[@"fit", @"placeholder"]];
    } else if ([type isEqualToString:@"input"]) {
        [allowed addObjectsFromArray:@[@"color", @"fontSize", @"align", @"hintColor", @"lines"]];
    } else if ([type isEqualToString:@"checkbox"] || [type isEqualToString:@"radio"] || [type isEqualToString:@"switch"]) {
        [allowed addObjectsFromArray:@[@"color", @"fontSize", @"tint"]];
    } else if ([type isEqualToString:@"progress"]) {
        [allowed addObjectsFromArray:@[@"track", @"bar"]];
    }
    if (![JSONReader requireKeys:style path:path allowed:allowed required:@[] error:error]) {
        return NO;
    }
    if (style.isEmpty) {
        return OTFail(error, [NSString stringWithFormat:@"%@ 不能是空对象", path]);
    }
    if ([style containsKey:@"background"] && [style containsKey:@"glass"]) {
        return OTFail(error, [NSString stringWithFormat:@"%@ 不能同时写 background 和 glass", path]);
    }
    if ([style containsKey:@"background"]) {
        NSString *background = OTBackgroundValue([style get:@"background"], [path stringByAppendingString:@".background"], error);
        if (background == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_BACKGROUND]] = background;
    }
    if ([style containsKey:@"radius"]) {
        if (!OTParseRadius([style get:@"radius"], [path stringByAppendingString:@".radius"], attrs, error)) {
            return NO;
        }
    }
    if ([style containsKey:@"border"]) {
        JSONObject *border = [JSONReader requireObject:[style get:@"border"]
                                                   path:[path stringByAppendingString:@".border"]
                                                  error:error];
        if (border == nil || !OTParseBorder(border, [path stringByAppendingString:@".border"], attrs, error)) {
            return NO;
        }
    }
    if ([style containsKey:@"glass"]) {
        JSONObject *glass = [JSONReader requireObject:[style get:@"glass"]
                                                 path:[path stringByAppendingString:@".glass"]
                                                error:error];
        if (glass == nil || !OTParseGlass(glass, [path stringByAppendingString:@".glass"], attrs, error)) {
            return NO;
        }
    }
    if ([style containsKey:@"color"]) {
        NSString *color = OTColorValue([style get:@"color"], [path stringByAppendingString:@".color"], error);
        if (color == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_TEXT_COLOR]] = color;
    }
    if ([style containsKey:@"fontSize"]) {
        NSString *fontSize = OTPlainNumber([style get:@"fontSize"], [path stringByAppendingString:@".fontSize"], error);
        if (fontSize == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_TEXT_SIZE]] = fontSize;
    }
    if ([style containsKey:@"align"]) {
        NSString *align = [JSONReader requireString:[style get:@"align"] path:[path stringByAppendingString:@".align"] error:error];
        if (align == nil) {
            return NO;
        }
        if (![[NSSet setWithObjects:@"start", @"center", @"end", nil] containsObject:align]) {
            return OTFail(error, [NSString stringWithFormat:@"%@.align 只能是 start、center、end", path]);
        }
        attrs[[TemplateKey ATTR_TEXT_ALIGN]] = align;
    }
    if ([style containsKey:@"hintColor"]) {
        NSString *hintColor = OTColorValue([style get:@"hintColor"], [path stringByAppendingString:@".hintColor"], error);
        if (hintColor == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_HINT_COLOR]] = hintColor;
    }
    if ([style containsKey:@"tint"]) {
        NSString *tint = OTColorValue([style get:@"tint"], [path stringByAppendingString:@".tint"], error);
        if (tint == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_TINT]] = tint;
    }
    if ([style containsKey:@"track"]) {
        NSString *track = OTPaintValue([style get:@"track"], [path stringByAppendingString:@".track"], error);
        if (track == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_STROKE_COLOR]] = track;
    }
    if ([style containsKey:@"bar"]) {
        NSString *bar = OTPaintValue([style get:@"bar"], [path stringByAppendingString:@".bar"], error);
        if (bar == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_TRAIL_COLOR]] = bar;
    }
    if ([style containsKey:@"maxLines"]) {
        NSString *maxLines = OTPositiveInt([style get:@"maxLines"], [path stringByAppendingString:@".maxLines"], error);
        if (maxLines == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_MAX_LINES]] = maxLines;
    }
    if ([style containsKey:@"ellipsis"]) {
        NSString *ellipsis = OTBoolString([style get:@"ellipsis"], [path stringByAppendingString:@".ellipsis"], error);
        if (ellipsis == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_ELLIPSIS]] = ellipsis;
    }
    if ([style containsKey:@"fontWeight"]) {
        NSString *weight = [JSONReader requireString:[style get:@"fontWeight"]
                                                path:[path stringByAppendingString:@".fontWeight"]
                                               error:error];
        if (weight == nil) {
            return NO;
        }
        if (![[NSSet setWithObjects:@"regular", @"medium", @"bold", nil] containsObject:weight]) {
            return OTFail(error, [NSString stringWithFormat:@"%@.fontWeight 只能是 regular、medium、bold", path]);
        }
        attrs[[TemplateKey ATTR_FONT_WEIGHT]] = weight;
    }
    if ([style containsKey:@"fit"]) {
        NSString *fit = [JSONReader requireString:[style get:@"fit"] path:[path stringByAppendingString:@".fit"] error:error];
        if (fit == nil) {
            return NO;
        }
        if (![[NSSet setWithObjects:@"cover", @"contain", @"fill", nil] containsObject:fit]) {
            return OTFail(error, [NSString stringWithFormat:@"%@.fit 只能是 cover、contain、fill", path]);
        }
        attrs[[TemplateKey ATTR_IMAGE_FIT]] = fit;
    }
    if ([style containsKey:@"placeholder"]) {
        NSString *placeholder = OTSolidColor([style get:@"placeholder"], [path stringByAppendingString:@".placeholder"], error);
        if (placeholder == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_PLACEHOLDER]] = placeholder;
    }
    if ([style containsKey:@"lines"]) {
        NSString *lines = OTPositiveInt([style get:@"lines"], [path stringByAppendingString:@".lines"], error);
        if (lines == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_LINES]] = lines;
    }
    return YES;
}

static BOOL OTParseListFields(JSONObject *node, NSString *path, NSMutableDictionary<NSString *, NSString *> *attrs, NSError **error) {
    NSString *data = [JSONReader requireString:[node get:@"data"] path:[path stringByAppendingString:@".data"] error:error];
    if (data == nil) {
        return NO;
    }
    if (![data hasPrefix:@"$"]) {
        return OTFail(error, [NSString stringWithFormat:@"%@.data 必须是 $ 开头的表达式", path]);
    }
    attrs[[TemplateKey ATTR_DATA]] = data;
    NSString *direction = @"vertical";
    if ([node containsKey:@"direction"]) {
        direction = [JSONReader requireString:[node get:@"direction"] path:[path stringByAppendingString:@".direction"] error:error];
        if (direction == nil) {
            return NO;
        }
    }
    if (![direction isEqualToString:@"horizontal"] && ![direction isEqualToString:@"vertical"]) {
        return OTFail(error, [NSString stringWithFormat:@"%@.direction 只能是 horizontal 或 vertical", path]);
    }
    attrs[[TemplateKey ATTR_LIST_DIRECTION]] = direction;
    if ([node containsKey:@"gap"]) {
        NSString *gap = OTPlainNumber([node get:@"gap"], [path stringByAppendingString:@".gap"], error);
        if (gap == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_ITEM_PADDING]] = gap;
    }
    return YES;
}

static BOOL OTParseProgressFields(JSONObject *node, NSString *path, NSMutableDictionary<NSString *, NSString *> *attrs, NSError **error) {
    if ([node containsKey:@"from"]) {
        NSString *from = OTFractionValue([node get:@"from"], [path stringByAppendingString:@".from"], error);
        if (from == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_VALUE_MIN]] = from;
    }
    if ([node containsKey:@"to"]) {
        NSString *to = OTFractionValue([node get:@"to"], [path stringByAppendingString:@".to"], error);
        if (to == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_VALUE_MAX]] = to;
    }
    if ([node containsKey:@"animate"]) {
        NSString *animate = OTBoolString([node get:@"animate"], [path stringByAppendingString:@".animate"], error);
        if (animate == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_ANIMATE_ENABLE]] = animate;
    }
    return YES;
}

static BOOL OTParseInputFields(JSONObject *node, NSString *path, NSMutableDictionary<NSString *, NSString *> *attrs, NSError **error) {
    if ([node containsKey:@"value"]) {
        NSString *text = [JSONReader requireString:[node get:@"value"] path:[path stringByAppendingString:@".value"] error:error];
        if (text == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_TEXT]] = text;
    }
    if ([node containsKey:@"hint"]) {
        NSString *hint = [JSONReader requireString:[node get:@"hint"] path:[path stringByAppendingString:@".hint"] error:error];
        if (hint == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_HINT]] = hint;
    }
    NSString *keyboard = @"text";
    if ([node containsKey:@"keyboard"]) {
        keyboard = [JSONReader requireString:[node get:@"keyboard"] path:[path stringByAppendingString:@".keyboard"] error:error];
        if (keyboard == nil) {
            return NO;
        }
    }
    NSSet *keyboardValues = [NSSet setWithObjects:@"text", @"number", @"password", @"email", @"phone", nil];
    if (![keyboardValues containsObject:keyboard]) {
        return OTFail(error, [NSString stringWithFormat:@"%@.keyboard 只能是 text、number、password、email、phone", path]);
    }
    attrs[[TemplateKey ATTR_INPUT_TYPE]] = keyboard;
    if ([node containsKey:@"maxLength"]) {
        NSString *maxLength = OTNonNegativeInt([node get:@"maxLength"], [path stringByAppendingString:@".maxLength"], error);
        if (maxLength == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_MAX_LENGTH]] = maxLength;
    }
    if ([node containsKey:@"lines"]) {
        NSString *lines = OTPositiveInt([node get:@"lines"], [path stringByAppendingString:@".lines"], error);
        if (lines == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_LINES]] = lines;
    }
    return YES;
}

static BOOL OTParseCheckBoxFields(JSONObject *node, NSString *path, NSMutableDictionary<NSString *, NSString *> *attrs, NSError **error) {
    if ([node containsKey:@"checked"]) {
        NSString *checked = OTCheckedValue([node get:@"checked"], [path stringByAppendingString:@".checked"], error);
        if (checked == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_CHECKED]] = checked;
    } else {
        attrs[[TemplateKey ATTR_CHECKED]] = @"false";
    }
    if ([node containsKey:@"label"]) {
        NSString *label = [JSONReader requireString:[node get:@"label"] path:[path stringByAppendingString:@".label"] error:error];
        if (label == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_TEXT]] = label;
    }
    return YES;
}

static BOOL OTParseRadioFields(JSONObject *node, NSString *path, NSMutableDictionary<NSString *, NSString *> *attrs, NSError **error) {
    if (!OTParseCheckBoxFields(node, path, attrs, error)) {
        return NO;
    }
    NSString *group = OTGroupValue([node get:@"group"], [path stringByAppendingString:@".group"], error);
    if (group == nil) {
        return NO;
    }
    attrs[[TemplateKey ATTR_GROUP]] = group;
    return YES;
}

static BOOL OTParseLottieFields(JSONObject *node, NSString *path, NSMutableDictionary<NSString *, NSString *> *attrs, NSError **error) {
    NSString *src = [JSONReader requireString:[node get:@"src"] path:[path stringByAppendingString:@".src"] error:error];
    if (src == nil) {
        return NO;
    }
    attrs[[TemplateKey ATTR_ANIMATION_SRC]] = src;
    if ([node containsKey:@"repeat"]) {
        NSString *repeat = OTRepeatValue([node get:@"repeat"], [path stringByAppendingString:@".repeat"], error);
        if (repeat == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_ANI_REPEAT_COUNT]] = repeat;
    } else {
        attrs[[TemplateKey ATTR_ANI_REPEAT_COUNT]] = @"infinite";
    }
    if ([node containsKey:@"mode"]) {
        NSString *mode = [JSONReader requireString:[node get:@"mode"] path:[path stringByAppendingString:@".mode"] error:error];
        if (mode == nil) {
            return NO;
        }
        if (![mode isEqualToString:@"restart"] && ![mode isEqualToString:@"reverse"]) {
            return OTFail(error, [NSString stringWithFormat:@"%@.mode 只能是 restart 或 reverse", path]);
        }
        attrs[[TemplateKey ATTR_ANI_REPEAT_MODE]] = mode;
    } else {
        attrs[[TemplateKey ATTR_ANI_REPEAT_MODE]] = @"restart";
    }
    if ([node containsKey:@"autoPlay"]) {
        NSString *autoPlay = OTBoolString([node get:@"autoPlay"], [path stringByAppendingString:@".autoPlay"], error);
        if (autoPlay == nil) {
            return NO;
        }
        attrs[[TemplateKey ATTR_ANI_AUTO_PLAY]] = autoPlay;
    } else {
        attrs[[TemplateKey ATTR_ANI_AUTO_PLAY]] = @"true";
    }
    return YES;
}

static ParsedNode *OTParseNode(JSONObject *node,
                               NSString *path,
                               NSMutableSet<NSString *> *ids,
                               NSMutableArray<NSString *> *clicks,
                               NSMutableArray<NSString *> *changes,
                               NSError **error) {
    if ([node get:@"type"].kind != JSONValueKindString) {
        OTFail(error, [NSString stringWithFormat:@"%@ 缺少 type", path]);
        return nil;
    }
    NSString *type = [node get:@"type"].string;
    NSString *viewName = OTViewNames()[type];
    if (viewName == nil) {
        OTFail(error, [NSString stringWithFormat:@"%@.type「%@」无法识别", path, type]);
        return nil;
    }
    BOOL isContainer = [type isEqualToString:@"column"] || [type isEqualToString:@"row"];
    NSMutableSet<NSString *> *allowed = [NSMutableSet setWithArray:@[@"type", @"id", @"layout", @"style", @"onClick", @"onChange", @"visible"]];
    NSMutableArray<NSString *> *required = [NSMutableArray arrayWithObjects:@"type", @"layout", nil];
    if ([type isEqualToString:@"column"]) {
        [allowed addObject:@"children"];
        [allowed addObject:@"scroll"];
    } else if ([type isEqualToString:@"row"]) {
        [allowed addObject:@"children"];
    } else if ([type isEqualToString:@"text"]) {
        [allowed addObject:@"text"];
        [required addObject:@"text"];
    } else if ([type isEqualToString:@"image"]) {
        [allowed addObject:@"src"];
        [required addObject:@"src"];
    } else if ([type isEqualToString:@"list"]) {
        [allowed addObjectsFromArray:@[@"data", @"direction", @"gap", @"item"]];
        [required addObjectsFromArray:@[@"id", @"data", @"item"]];
    } else if ([type isEqualToString:@"progress"]) {
        [allowed addObjectsFromArray:@[@"from", @"to", @"animate"]];
    } else if ([type isEqualToString:@"lottie"]) {
        [allowed addObjectsFromArray:@[@"src", @"repeat", @"mode", @"autoPlay"]];
        [required addObject:@"src"];
    } else if ([type isEqualToString:@"input"]) {
        [allowed addObjectsFromArray:@[@"value", @"hint", @"keyboard", @"maxLength", @"lines"]];
    } else if ([type isEqualToString:@"checkbox"] || [type isEqualToString:@"switch"]) {
        [allowed addObjectsFromArray:@[@"checked", @"label"]];
    } else if ([type isEqualToString:@"radio"]) {
        [allowed addObjectsFromArray:@[@"checked", @"label", @"group"]];
        [required addObject:@"group"];
    }
    if (![JSONReader requireKeys:node path:path allowed:allowed required:required error:error]) {
        return nil;
    }
    NSString *nodeId = @"0";
    if ([node containsKey:@"id"]) {
        nodeId = OTRequireName([node get:@"id"], [path stringByAppendingString:@".id"], error);
        if (nodeId == nil) {
            return nil;
        }
    }
    if (![nodeId isEqualToString:@"0"]) {
        [ids addObject:nodeId];
    }
    NSMutableDictionary<NSString *, NSString *> *attrs = [NSMutableDictionary dictionary];
    if (![nodeId isEqualToString:@"0"]) {
        attrs[[TemplateKey ATTR_ID]] = nodeId;
    }
    JSONObject *layout = [JSONReader requireObject:[node get:@"layout"] path:[path stringByAppendingString:@".layout"] error:error];
    if (layout == nil || !OTParseLayout(layout, [path stringByAppendingString:@".layout"], isContainer, attrs, error)) {
        return nil;
    }
    if ([node containsKey:@"style"]) {
        JSONObject *style = [JSONReader requireObject:[node get:@"style"] path:[path stringByAppendingString:@".style"] error:error];
        if (style == nil || !OTParseStyle(style, [path stringByAppendingString:@".style"], type, attrs, error)) {
            return nil;
        }
    }
    if ([node containsKey:@"visible"]) {
        NSString *visible = OTCheckedValue([node get:@"visible"], [path stringByAppendingString:@".visible"], error);
        if (visible == nil) {
            return nil;
        }
        attrs[[TemplateKey ATTR_VISIBLE]] = visible;
    }
    if ([node containsKey:@"onClick"]) {
        NSArray<NSString *> *names = OTParseNames([node get:@"onClick"], [path stringByAppendingString:@".onClick"], error);
        if (names == nil) {
            return nil;
        }
        if (names.count == 0) {
            OTFail(error, [NSString stringWithFormat:@"%@.onClick 不能是空数组", path]);
            return nil;
        }
        [clicks addObjectsFromArray:names];
        attrs[[TemplateKey ATTR_ONCLICK]] = [names componentsJoinedByString:@","];
    }
    if ([node containsKey:@"onChange"]) {
        NSArray<NSString *> *names = OTParseNames([node get:@"onChange"], [path stringByAppendingString:@".onChange"], error);
        if (names == nil) {
            return nil;
        }
        if (names.count == 0) {
            OTFail(error, [NSString stringWithFormat:@"%@.onChange 不能是空数组", path]);
            return nil;
        }
        [changes addObjectsFromArray:names];
        attrs[[TemplateKey ATTR_ONCHANGE]] = [names componentsJoinedByString:@","];
    }
    if ([node containsKey:@"scroll"]) {
        NSString *scroll = OTBoolString([node get:@"scroll"], [path stringByAppendingString:@".scroll"], error);
        if (scroll == nil) {
            return nil;
        }
        attrs[[TemplateKey ATTR_SCROLL]] = scroll;
    }
    if ([type isEqualToString:@"text"]) {
        NSString *text = [JSONReader requireString:[node get:@"text"] path:[path stringByAppendingString:@".text"] error:error];
        if (text == nil) {
            return nil;
        }
        attrs[[TemplateKey ATTR_TEXT]] = text;
    } else if ([type isEqualToString:@"image"]) {
        NSString *src = [JSONReader requireString:[node get:@"src"] path:[path stringByAppendingString:@".src"] error:error];
        if (src == nil) {
            return nil;
        }
        attrs[[TemplateKey ATTR_SRC]] = src;
    } else if ([type isEqualToString:@"list"]) {
        if (!OTParseListFields(node, path, attrs, error)) {
            return nil;
        }
    } else if ([type isEqualToString:@"progress"]) {
        if (!OTParseProgressFields(node, path, attrs, error)) {
            return nil;
        }
    } else if ([type isEqualToString:@"lottie"]) {
        if (!OTParseLottieFields(node, path, attrs, error)) {
            return nil;
        }
    } else if ([type isEqualToString:@"input"]) {
        if (!OTParseInputFields(node, path, attrs, error)) {
            return nil;
        }
    } else if ([type isEqualToString:@"checkbox"] || [type isEqualToString:@"switch"]) {
        if (!OTParseCheckBoxFields(node, path, attrs, error)) {
            return nil;
        }
    } else if ([type isEqualToString:@"radio"]) {
        if (!OTParseRadioFields(node, path, attrs, error)) {
            return nil;
        }
    }
    NSMutableArray<ParsedNode *> *children = [NSMutableArray array];
    if (isContainer && [node containsKey:@"children"]) {
        JSONArray *array = [JSONReader requireArray:[node get:@"children"] path:[path stringByAppendingString:@".children"] error:error];
        if (array == nil) {
            return nil;
        }
        for (NSInteger index = 0; index < array.size; index++) {
            NSString *childPath = [NSString stringWithFormat:@"%@.children[%ld]", path, (long)index];
            JSONObject *child = [JSONReader requireObject:[array get:index] path:childPath error:error];
            if (child == nil) {
                return nil;
            }
            ParsedNode *parsed = OTParseNode(child, childPath, ids, clicks, changes, error);
            if (parsed == nil) {
                return nil;
            }
            [children addObject:parsed];
        }
    }
    ParsedNode *item = nil;
    if ([type isEqualToString:@"list"]) {
        JSONObject *itemObject = [JSONReader requireObject:[node get:@"item"] path:[path stringByAppendingString:@".item"] error:error];
        if (itemObject == nil) {
            return nil;
        }
        item = OTParseNode(itemObject, [path stringByAppendingString:@".item"], ids, clicks, changes, error);
        if (item == nil) {
            return nil;
        }
    }
    return [[ParsedNode alloc] initWithViewName:viewName id:nodeId attrs:attrs children:children item:item];
}

@implementation TemplateJsonParser

+ (ParsedTemplate *)parseJSON:(NSString *)json error:(NSError **)error {
    JSONObject *root = [JSONReader rootObjectFromJSON:json
                                        invalidPrefix:@"模版不是合法 JSON："
                                            notObject:@"模版必须是 JSON 对象"
                                                error:error];
    if (root == nil) {
        return nil;
    }
    if (![JSONReader requireKeys:root
                            path:@"$"
                         allowed:[NSSet setWithObjects:@"layout", @"events", nil]
                        required:@[@"layout"]
                           error:error]) {
        return nil;
    }
    NSMutableArray<NSString *> *eventNames = [NSMutableArray array];
    NSMutableArray<JSONObject *> *eventObjects = [NSMutableArray array];
    if (!OTParseEvents([root get:@"events"], @"$.events", eventNames, eventObjects, error)) {
        return nil;
    }
    NSMutableDictionary<NSString *, JSONObject *> *events = [NSMutableDictionary dictionary];
    for (NSUInteger index = 0; index < eventNames.count; index++) {
        events[eventNames[index]] = eventObjects[index];
    }
    NSMutableSet<NSString *> *ids = [NSMutableSet set];
    NSMutableArray<NSString *> *clicks = [NSMutableArray array];
    NSMutableArray<NSString *> *changes = [NSMutableArray array];
    JSONObject *layout = [JSONReader requireObject:[root get:@"layout"] path:@"$.layout" error:error];
    if (layout == nil) {
        return nil;
    }
    ParsedNode *parsedLayout = OTParseNode(layout, @"$.layout", ids, clicks, changes, error);
    if (parsedLayout == nil) {
        return nil;
    }
    for (NSString *name in clicks) {
        if (events[name] == nil) {
            OTFail(error, [NSString stringWithFormat:@"onClick 引用了不存在的事件 %@", name]);
            return nil;
        }
    }
    for (NSString *name in changes) {
        if (events[name] == nil) {
            OTFail(error, [NSString stringWithFormat:@"onChange 引用了不存在的事件 %@", name]);
            return nil;
        }
    }
    for (NSUInteger index = 0; index < eventNames.count; index++) {
        NSString *name = eventNames[index];
        JSONObject *event = eventObjects[index];
        JSONObject *params = [event getJSONObject:@"params"];
        if (params == nil) {
            continue;
        }
        NSMutableArray<NSString *> *targets = [NSMutableArray array];
        NSString *idList = [params getString:@"id"];
        if (idList != nil) {
            [targets addObjectsFromArray:[idList componentsSeparatedByString:@","]];
        }
        NSString *from = [params getString:@"from"];
        if (from != nil) {
            [targets addObject:from];
        }
        for (NSString *targetId in targets) {
            if (targetId.length > 0 && ![ids containsObject:targetId]) {
                OTFail(error, [NSString stringWithFormat:@"事件 %@ 的 target「%@」在模版中不存在", name, targetId]);
                return nil;
            }
        }
    }
    return [[ParsedTemplate alloc] initWithRoot:parsedLayout events:events];
}

@end
