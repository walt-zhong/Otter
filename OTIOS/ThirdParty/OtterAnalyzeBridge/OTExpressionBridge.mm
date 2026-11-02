//
//  OTExpressionBridge.mm
//
//  ObjC++ subclass of the existing OTAnalyze C++ engine
//  (OTAndroid/src/main/cpp). Does not reimplement the grammar.
//
//  Bridging technique mirrors:
//    GXAnalyzeImpl.mm  — virtual methods forward to ObjC
//    GXNativeAnalyze.mm — getValue then unwrap the OTValue pointer
//    GXContext.mm — tag switch to object values
//  Number tags and functions follow ExpressionWrapper.kt and
//  OTJniAnalyze.cpp, not GXContext's "every non-bool is float"
//  and not GXFunction's integer size() / empty env().
//

#import "OTExpressionBridge.h"

#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>

#include "OTAnalyze.h"

static long OTCreateBool(BOOL value) {
    OTValue *result = new OTValue(OT_TAG_BOOL, (int32_t)(value ? 1 : 0));
    return (long)result;
}

static long OTCreateLong(int64_t value) {
    OTValue *result = new OTValue(OT_TAG_LONG, value);
    return (long)result;
}

static long OTCreateFloat(float value) {
    OTValue *result = new OTValue(OT_TAG_FLOAT, value);
    return (long)result;
}

static long OTCreateString(NSString *value) {
    const char *utf8 = value.UTF8String;
    OTValue *result = new OTValue(OT_TAG_STRING, utf8 != NULL ? utf8 : "");
    return (long)result;
}

static long OTCreateNull(void) {
    // JNI createValueNull stores the int 1, same as the engine's null token.
    OTValue *result = new OTValue(OT_TAG_NULL, 1);
    return (long)result;
}

static long OTCreateArray(id value) {
    OTValue *result = new OTValue(OT_TAG_ARRAY, (__bridge void *)value);
    return (long)result;
}

static long OTCreateMap(id value) {
    OTValue *result = new OTValue(OT_TAG_MAP, (__bridge void *)value);
    return (long)result;
}

static void OTReleaseHeld(long address) {
    if (address == 0) {
        return;
    }
    OTValue *val = (OTValue *)address;
    if (val->tag == OT_TAG_STRING && val->str != NULL) {
        delete[] val->str;
        val->str = NULL;
    }
    releaseGXValue(address);
}

// ExpressionWrapper.computeValueExpression number branches:
//   Boolean -> createValueBool
//   Int / Long -> createValueLong
//   Float -> createValueFloat64(float)
//   Double / BigDecimal -> createValueFloat64(toFloat())
static long OTBoxJSONNumber(NSNumber *number) {
    if (CFGetTypeID((__bridge CFTypeRef)number) == CFBooleanGetTypeID()) {
        return OTCreateBool(number.boolValue);
    }
    const char *type = number.objCType;
    if (strcmp(type, @encode(float)) == 0) {
        return OTCreateFloat(number.floatValue);
    }
    if (strcmp(type, @encode(double)) == 0) {
        // Double.toFloat() / BigDecimal.toFloat(): narrow to float32.
        return OTCreateFloat(static_cast<float>(number.doubleValue));
    }
    // Kotlin Int is 32-bit ("i"). Kotlin Long and Swift Int are 64-bit
    // ("q" on LP64, which is also @encode(long) and @encode(long long)).
    if (strcmp(type, @encode(int)) == 0 ||
        strcmp(type, @encode(long)) == 0 ||
        strcmp(type, @encode(long long)) == 0) {
        return OTCreateLong(number.longLongValue);
    }
    NSLog(@"[SenseDyne] Not recognize value = %@", number);
    return 0;
}

static long OTBoxJSONValue(id value) {
    if (value == nil || value == [NSNull null]) {
        return OTCreateNull();
    }
    if ([value isKindOfClass:[NSString class]]) {
        return OTCreateString((NSString *)value);
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        return OTBoxJSONNumber((NSNumber *)value);
    }
    if ([value isKindOfClass:[NSArray class]]) {
        return OTCreateArray(value);
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        return OTCreateMap(value);
    }
    NSLog(@"[SenseDyne] Not recognize value = %@", value);
    return 0;
}

// Kotlin String.toInt(): whole base-10 integer in Int range, no spaces.
static BOOL OTKotlinToInt(NSString *text, int32_t *outValue) {
    if (text.length == 0 || outValue == NULL) {
        return NO;
    }
    const char *utf8 = text.UTF8String;
    if (utf8 == NULL) {
        return NO;
    }
    errno = 0;
    char *end = NULL;
    long long parsed = strtoll(utf8, &end, 10);
    if (end == utf8 || end == NULL || *end != '\0' || errno == ERANGE) {
        return NO;
    }
    if (parsed < INT32_MIN || parsed > INT32_MAX) {
        return NO;
    }
    *outValue = (int32_t)parsed;
    return YES;
}

// JSON.getAnyExt in OTAndroid/.../utils/OTJsonExt.kt.
static id OTGetAnyExt(id json, NSString *valuePath) {
    if (valuePath == nil) {
        return nil;
    }
    @try {
        NSRange dot = [valuePath rangeOfString:@"."];
        NSRange left = [valuePath rangeOfString:@"["];
        NSRange right = [valuePath rangeOfString:@"]"];
        BOOL hasDot = dot.location != NSNotFound;
        BOOL hasLeft = left.location != NSNotFound;
        BOOL hasRight = right.location != NSNotFound;

        if (!hasDot && hasLeft && hasRight && left.location < right.location) {
            NSString *arrayName = [valuePath substringToIndex:left.location];
            NSString *indexText = [valuePath substringWithRange:NSMakeRange(left.location + 1,
                                                                            right.location - left.location - 1)];
            int32_t arrayIndex = 0;
            if (!OTKotlinToInt(indexText, &arrayIndex)) {
                return nil;
            }
            id array = nil;
            if ([json isKindOfClass:[NSDictionary class]]) {
                array = [(NSDictionary *)json objectForKey:arrayName];
            }
            if (![array isKindOfClass:[NSArray class]]) {
                return nil;
            }
            NSArray *items = (NSArray *)array;
            if (arrayIndex < 0 || (NSUInteger)arrayIndex >= items.count) {
                NSLog(@"Otter getAnyExt IndexOutOfBounds: XPath: %@ Index: %d, Size: %lu",
                      valuePath, arrayIndex, (unsigned long)items.count);
                return nil;
            }
            return items[(NSUInteger)arrayIndex];
        }

        if (!hasDot && !hasLeft && !hasRight) {
            if ([json isKindOfClass:[NSDictionary class]]) {
                return [(NSDictionary *)json objectForKey:valuePath];
            }
            return nil;
        }

        if (!hasDot) {
            // substring(0, keyIndex) throws when keyIndex == -1; caught below.
            return nil;
        }

        NSString *firstKey = [[valuePath substringToIndex:dot.location]
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *restKey = [valuePath substringFromIndex:dot.location + 1];
        id next = OTGetAnyExt(json, firstKey);
        if ([next isKindOfClass:[NSDictionary class]] || [next isKindOfClass:[NSArray class]]) {
            return OTGetAnyExt(next, restKey);
        }
        return nil;
    } @catch (NSException *exception) {
        NSLog(@"%@", exception);
        return nil;
    }
}

static long OTFunctionSize(long param) {
    if (param == 0) {
        return OTCreateFloat(0.f);
    }
    OTValue *val = (OTValue *)param;
    long result = 0;
    BOOL matched = NO;
    if (val->tag == OT_TAG_STRING) {
        matched = YES;
        if (val->str != NULL) {
            NSString *text = [NSString stringWithUTF8String:val->str];
            if (text != nil) {
                // Java String.length() is UTF-16 code units, same as NSString.length.
                result = OTCreateFloat((float)text.length);
            }
        }
    } else if (val->tag == OT_TAG_MAP) {
        matched = YES;
        id object = (__bridge id)val->ptr;
        if ([object isKindOfClass:[NSDictionary class]]) {
            result = OTCreateFloat((float)[(NSDictionary *)object count]);
        }
    } else if (val->tag == OT_TAG_ARRAY) {
        matched = YES;
        id object = (__bridge id)val->ptr;
        if ([object isKindOfClass:[NSArray class]]) {
            result = OTCreateFloat((float)[(NSArray *)object count]);
        }
    }
    OTReleaseHeld(param);
    if (!matched) {
        return OTCreateFloat(0.f);
    }
    // Matched but the Kotlin `?.let` did not return: fall through to 0L.
    return result;
}

static long OTFunctionEnv(long param) {
    if (param == 0) {
        return 0;
    }
    OTValue *val = (OTValue *)param;
    long result = 0;
    if (val->tag == OT_TAG_STRING && val->str != NULL) {
        NSString *envValue = [NSString stringWithUTF8String:val->str];
        if (envValue != nil) {
            // ExpressionWrapper.functionEnv, with the iOS flags flipped.
            if ([envValue caseInsensitiveCompare:@"isAndroid"] == NSOrderedSame) {
                result = OTCreateBool(NO);
            } else if ([envValue caseInsensitiveCompare:@"isiOS"] == NSOrderedSame) {
                result = OTCreateBool(YES);
            }
        }
    }
    OTReleaseHeld(param);
    return result;
}

@class OTExpressionBridge;

class OTAnalyzeHost : public OTAnalyze {
public:
    __unsafe_unretained OTExpressionBridge *bridge;

    long getSourceValue(string valuePath, void *source) override;
    long getFunctionValue(string funName, long *paramPointers, int paramsSize, string source) override;
    void throwError(string message) override;
};

@interface OTEvalBox ()
@property (nonatomic, assign) OTEvalKind kind;
@property (nonatomic, assign) BOOL boolValue;
@property (nonatomic, assign) int64_t longValue;
@property (nonatomic, assign) float floatValue;
@property (nonatomic, strong, nullable) id objectValue;
@end

@implementation OTEvalBox
@end

@interface OTExpressionBridge () {
    OTAnalyzeHost *_host;
}
- (long)sourceValueForPath:(const char *)path source:(id)source;
- (long)functionValueForName:(const char *)name params:(long *)params size:(int)size;
- (void)throwEngineError:(const char *)message;
@end

long OTAnalyzeHost::getSourceValue(string valuePath, void *source) {
    return [bridge sourceValueForPath:valuePath.c_str() source:(__bridge id)source];
}

long OTAnalyzeHost::getFunctionValue(string funName, long *paramPointers, int paramsSize, string source) {
    (void)source;
    return [bridge functionValueForName:funName.c_str() params:paramPointers size:paramsSize];
}

void OTAnalyzeHost::throwError(string message) {
    [bridge throwEngineError:message.c_str()];
}

@implementation OTExpressionBridge

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _host = new OTAnalyzeHost();
        _host->bridge = self;
    }
    return self;
}

- (void)dealloc {
    delete _host;
    _host = nullptr;
}

- (long)sourceValueForPath:(const char *)path source:(id)source {
    @autoreleasepool {
        if (path == NULL) {
            return 0;
        }
        NSString *valuePath = [NSString stringWithUTF8String:path];
        if (valuePath == nil) {
            return 0;
        }
        // ExpressionWrapper.computeValueExpression: "$$" is the whole source.
        if ([valuePath isEqualToString:@"$$"]) {
            if ([source isKindOfClass:[NSArray class]]) {
                return OTCreateArray(source);
            } else if ([source isKindOfClass:[NSDictionary class]]) {
                return OTCreateMap(source);
            }
        }
        if ([source isKindOfClass:[NSDictionary class]]) {
            id value = OTGetAnyExt(source, valuePath);
            if (value == nil || value == [NSNull null]) {
                return OTCreateNull();
            }
            return OTBoxJSONValue(value);
        }
        return 0;
    }
}

- (long)functionValueForName:(const char *)name params:(long *)params size:(int)size {
    @autoreleasepool {
        NSString *functionName = name != NULL ? [NSString stringWithUTF8String:name] : nil;
        if (size == 1 && params != NULL && functionName != nil) {
            if ([functionName isEqualToString:@"size"]) {
                return OTFunctionSize(params[0]);
            }
            if ([functionName isEqualToString:@"env"]) {
                return OTFunctionEnv(params[0]);
            }
        }
        if (params != NULL) {
            for (int index = 0; index < size; index++) {
                OTReleaseHeld(params[index]);
            }
        }
        return 0;
    }
}

- (void)throwEngineError:(const char *)message {
    // OTJniAnalyze.cpp logs and does not abort. NSAssert would fail
    // expressions the Android tests evaluate as null.
    NSLog(@"[SenseDyne] %s", message != NULL ? message : "");
}

- (OTEvalBox *)evaluateString:(NSString *)expression data:(id)data {
    if (expression == nil || _host == nullptr) {
        return nil;
    }
    const char *utf8 = expression.UTF8String;
    if (utf8 == NULL) {
        return nil;
    }
    @autoreleasepool {
        long address = _host->getValue(std::string(utf8), (__bridge void *)data);
        if (address == 0) {
            return nil;
        }
        OTValue *val = (OTValue *)address;
        OTEvalBox *box = [[OTEvalBox alloc] init];
        BOOL recognized = YES;
        switch (val->tag) {
            case OT_TAG_BOOL:
                box.kind = OTEvalKindBool;
                box.boolValue = val->int32 ? YES : NO;
                break;
            case OT_TAG_FLOAT:
                box.kind = OTEvalKindFloat;
                box.floatValue = val->float64;
                break;
            case OT_TAG_LONG:
                box.kind = OTEvalKindLong;
                box.longValue = val->intNum;
                break;
            case OT_TAG_STRING:
                box.kind = OTEvalKindString;
                box.objectValue = val->str != NULL ? [NSString stringWithUTF8String:val->str] : @"";
                if (box.objectValue == nil) {
                    box.objectValue = @"";
                }
                break;
            case OT_TAG_ARRAY:
                box.kind = OTEvalKindArray;
                box.objectValue = (__bridge id)val->ptr;
                break;
            case OT_TAG_MAP:
                box.kind = OTEvalKindMap;
                box.objectValue = (__bridge id)val->ptr;
                break;
            case OT_TAG_NULL:
                recognized = NO;
                break;
            default:
                recognized = NO;
                break;
        }
        OTReleaseHeld(address);
        return recognized ? box : nil;
    }
}

@end
