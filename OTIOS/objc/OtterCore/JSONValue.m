#import "JSONValue.h"

#include <locale.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <xlocale.h>

NSErrorDomain const TemplateParseExceptionDomain = @"TemplateParseException";

NSError *TemplateParseExceptionError(NSString *message) {
    return [NSError errorWithDomain:TemplateParseExceptionDomain
                               code:0
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @""}];
}

static BOOL OTReject(NSError **error, NSString *message) {
    if (error != NULL) {
        *error = TemplateParseExceptionError(message);
    }
    return NO;
}

static locale_t OTCLocale(void) {
    static locale_t locale;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        locale = newlocale(LC_NUMERIC_MASK, "C", NULL);
    });
    return locale;
}

static int OTDoublesEqual(double left, double right) {
    uint64_t leftBits = 0;
    uint64_t rightBits = 0;
    memcpy(&leftBits, &left, sizeof(leftBits));
    memcpy(&rightBits, &right, sizeof(rightBits));
    return leftBits == rightBits;
}

static int OTParseGeneral(const char *text, char *digits, int *exponent, int *negative) {
    *negative = 0;
    if (*text == '-') {
        *negative = 1;
        text++;
    }
    const char *exponentMark = strchr(text, 'e');
    if (exponentMark == NULL) {
        exponentMark = strchr(text, 'E');
    }
    char mantissa[64];
    int explicitExponent = 0;
    if (exponentMark != NULL) {
        size_t length = (size_t)(exponentMark - text);
        if (length >= sizeof(mantissa)) {
            return 0;
        }
        memcpy(mantissa, text, length);
        mantissa[length] = '\0';
        explicitExponent = atoi(exponentMark + 1);
    } else {
        snprintf(mantissa, sizeof(mantissa), "%s", text);
    }
    char raw[64];
    int dot = -1;
    int rawLength = 0;
    for (int index = 0; mantissa[index] != '\0'; index++) {
        if (mantissa[index] == '.') {
            dot = rawLength;
            continue;
        }
        raw[rawLength++] = mantissa[index];
    }
    raw[rawLength] = '\0';
    if (dot < 0) {
        dot = rawLength;
    }
    int lead = 0;
    while (raw[lead] == '0' && raw[lead + 1] != '\0') {
        lead++;
    }
    if (raw[lead] == '0') {
        digits[0] = '0';
        digits[1] = '\0';
        *exponent = 0;
        return 1;
    }
    int digitsBeforeDot = dot - lead;
    snprintf(digits, 64, "%s", raw + lead);
    int length = (int)strlen(digits);
    while (length > 1 && digits[length - 1] == '0') {
        digits[--length] = '\0';
    }
    *exponent = explicitExponent + digitsBeforeDot - 1;
    return 1;
}

static void OTFormatSwiftDigits(char *dest, int negative, const char *digits, int exponent, int forceExponential) {
    char *cursor = dest;
    if (negative) {
        *cursor++ = '-';
    }
    int length = (int)strlen(digits);
    if (exponent < -4 || forceExponential) {
        *cursor++ = digits[0];
        if (length > 1) {
            *cursor++ = '.';
            memcpy(cursor, digits + 1, (size_t)(length - 1));
            cursor += length - 1;
        }
        *cursor++ = 'e';
        if (exponent < 0) {
            *cursor++ = '-';
            exponent = -exponent;
        } else {
            *cursor++ = '+';
        }
        if (exponent > 99) {
            *cursor++ = (char)('0' + exponent / 100);
            exponent %= 100;
        }
        sprintf(cursor, "%02d", exponent);
        return;
    }
    if (exponent < 0) {
        *cursor++ = '0';
        *cursor++ = '.';
        for (int index = 0; index < -exponent - 1; index++) {
            *cursor++ = '0';
        }
        memcpy(cursor, digits, (size_t)length);
        cursor[length] = '\0';
        return;
    }
    if (exponent + 1 < length) {
        memcpy(cursor, digits, (size_t)(exponent + 1));
        cursor += exponent + 1;
        *cursor++ = '.';
        memcpy(cursor, digits + exponent + 1, (size_t)(length - exponent - 1));
        cursor[length - exponent - 1] = '\0';
        return;
    }
    memcpy(cursor, digits, (size_t)length);
    cursor += length;
    for (int index = 0; index < exponent + 1 - length; index++) {
        *cursor++ = '0';
    }
    *cursor++ = '.';
    *cursor++ = '0';
    *cursor = '\0';
}

static int OTForceExponential(double value) {
    int binaryExponent = 0;
    double fraction = frexp(fabs(value), &binaryExponent);
    int isBoundary = fraction == 0.5;
    return binaryExponent > 54 || (binaryExponent == 54 && !isBoundary);
}

static NSString *OTSwiftStringFromDouble(double value) {
    if (isnan(value)) {
        return @"nan";
    }
    if (isinf(value)) {
        return signbit(value) ? @"-inf" : @"inf";
    }
    if (value == 0.0) {
        return signbit(value) ? @"-0.0" : @"0.0";
    }
    char buffer[128];
    locale_t previous = uselocale(OTCLocale());
    int precision = 1;
    for (; precision <= 17; precision++) {
        snprintf(buffer, sizeof(buffer), "%.*g", precision, value);
        char *end = NULL;
        double parsed = strtod(buffer, &end);
        if (end != NULL && *end == '\0' && OTDoublesEqual(parsed, value)) {
            break;
        }
    }
    uselocale(previous);
    char digits[64];
    int exponent = 0;
    int negative = 0;
    if (!OTParseGeneral(buffer, digits, &exponent, &negative)) {
        return [NSString stringWithUTF8String:buffer];
    }
    char formatted[128];
    OTFormatSwiftDigits(formatted, negative, digits, exponent, OTForceExponential(value));
    return [NSString stringWithUTF8String:formatted];
}

@implementation JSONNumber {
    BOOL _isDouble;
    int64_t _intValue;
    double _doubleValue;
}

+ (instancetype)intNumber:(int64_t)value {
    JSONNumber *number = [[JSONNumber alloc] init];
    number->_isDouble = NO;
    number->_intValue = value;
    number->_doubleValue = (double)value;
    return number;
}

+ (instancetype)doubleNumber:(double)value {
    JSONNumber *number = [[JSONNumber alloc] init];
    number->_isDouble = YES;
    number->_doubleValue = value;
    number->_intValue = (int64_t)value;
    return number;
}

- (BOOL)isDouble {
    return _isDouble;
}

- (int64_t)intValue {
    return _intValue;
}

- (double)doubleValue {
    return _doubleValue;
}

- (NSString *)description {
    if (_isDouble) {
        return OTSwiftStringFromDouble(_doubleValue);
    }
    return [NSString stringWithFormat:@"%lld", (long long)_intValue];
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[JSONNumber class]]) {
        return NO;
    }
    JSONNumber *other = object;
    if (_isDouble != other->_isDouble) {
        return NO;
    }
    if (_isDouble) {
        return OTDoublesEqual(_doubleValue, other->_doubleValue);
    }
    return _intValue == other->_intValue;
}

- (NSUInteger)hash {
    if (_isDouble) {
        uint64_t bits = 0;
        memcpy(&bits, &_doubleValue, sizeof(bits));
        return (NSUInteger)bits;
    }
    return (NSUInteger)_intValue;
}

@end

@implementation JSONValue {
    JSONValueKind _kind;
    id _object;
    JSONNumber *_number;
    BOOL _boolValue;
}

+ (instancetype)object:(JSONObject *)object {
    JSONValue *value = [[JSONValue alloc] init];
    value->_kind = JSONValueKindObject;
    value->_object = object;
    return value;
}

+ (instancetype)array:(JSONArray *)array {
    JSONValue *value = [[JSONValue alloc] init];
    value->_kind = JSONValueKindArray;
    value->_object = array;
    return value;
}

+ (instancetype)string:(NSString *)string {
    JSONValue *value = [[JSONValue alloc] init];
    value->_kind = JSONValueKindString;
    value->_object = [string copy];
    return value;
}

+ (instancetype)number:(JSONNumber *)number {
    JSONValue *value = [[JSONValue alloc] init];
    value->_kind = JSONValueKindNumber;
    value->_number = number;
    return value;
}

+ (instancetype)bool:(BOOL)value {
    JSONValue *boxed = [[JSONValue alloc] init];
    boxed->_kind = JSONValueKindBool;
    boxed->_boolValue = value;
    return boxed;
}

+ (instancetype)null {
    JSONValue *value = [[JSONValue alloc] init];
    value->_kind = JSONValueKindNull;
    return value;
}

- (JSONValueKind)kind {
    return _kind;
}

- (NSString *)string {
    if (_kind == JSONValueKindString) {
        return _object;
    }
    return nil;
}

- (JSONObject *)jsonObject {
    if (_kind == JSONValueKindObject) {
        return _object;
    }
    return nil;
}

- (JSONArray *)jsonArray {
    if (_kind == JSONValueKindArray) {
        return _object;
    }
    return nil;
}

- (JSONNumber *)number {
    if (_kind == JSONValueKindNumber) {
        return _number;
    }
    return nil;
}

- (BOOL)boolValue {
    if (_kind == JSONValueKindBool) {
        return _boolValue;
    }
    return NO;
}

- (NSString *)description {
    switch (_kind) {
        case JSONValueKindObject:
        case JSONValueKindArray:
            return [_object description];
        case JSONValueKindString:
            return [NSString stringWithFormat:@"\"%@\"", _object];
        case JSONValueKindNumber:
            return [_number description];
        case JSONValueKindBool:
            return _boolValue ? @"true" : @"false";
        case JSONValueKindNull:
            return @"null";
    }
    return @"null";
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[JSONValue class]]) {
        return NO;
    }
    JSONValue *other = object;
    if (_kind != other->_kind) {
        return NO;
    }
    switch (_kind) {
        case JSONValueKindObject:
        case JSONValueKindArray:
        case JSONValueKindString:
            return [_object isEqual:other->_object];
        case JSONValueKindNumber:
            return [_number isEqual:other->_number];
        case JSONValueKindBool:
            return _boolValue == other->_boolValue;
        case JSONValueKindNull:
            return YES;
    }
    return NO;
}

- (NSUInteger)hash {
    switch (_kind) {
        case JSONValueKindObject:
        case JSONValueKindArray:
        case JSONValueKindString:
            return _kind ^ [_object hash];
        case JSONValueKindNumber:
            return _kind ^ [_number hash];
        case JSONValueKindBool:
            return _kind ^ (NSUInteger)_boolValue;
        case JSONValueKindNull:
            return _kind;
    }
    return _kind;
}

@end

@implementation JSONObject {
    NSMutableArray<NSString *> *_order;
    NSMutableDictionary<NSString *, JSONValue *> *_storage;
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _order = [NSMutableArray array];
        _storage = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSInteger)size {
    return (NSInteger)_order.count;
}

- (BOOL)isEmpty {
    return _order.count == 0;
}

- (NSArray<NSString *> *)keys {
    return [_order copy];
}

- (BOOL)containsKey:(NSString *)key {
    return _storage[key] != nil;
}

- (JSONValue *)get:(NSString *)key {
    return _storage[key];
}

- (NSString *)getString:(NSString *)key {
    return _storage[key].string;
}

- (JSONObject *)getJSONObject:(NSString *)key {
    return _storage[key].jsonObject;
}

- (JSONArray *)getJSONArray:(NSString *)key {
    return _storage[key].jsonArray;
}

- (BOOL)getBooleanValue:(NSString *)key {
    JSONValue *value = _storage[key];
    if (value.kind == JSONValueKindBool) {
        return value.boolValue;
    }
    return NO;
}

- (void)set:(JSONValue *)value forKey:(NSString *)key {
    if (key == nil) {
        return;
    }
    if (value == nil) {
        [_storage removeObjectForKey:key];
        [_order removeObject:key];
        return;
    }
    if (_storage[key] == nil) {
        [_order addObject:key];
    }
    _storage[key] = value;
}

- (JSONValue *)objectForKeyedSubscript:(NSString *)key {
    return [self get:key];
}

- (void)setObject:(JSONValue *)object forKeyedSubscript:(NSString *)key {
    [self set:object forKey:key];
}

- (NSString *)description {
    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithCapacity:_order.count];
    for (NSString *key in _order) {
        JSONValue *value = _storage[key];
        [parts addObject:[NSString stringWithFormat:@"%@: %@", key, value.description ?: @"null"]];
    }
    return [NSString stringWithFormat:@"{%@}", [parts componentsJoinedByString:@", "]];
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[JSONObject class]]) {
        return NO;
    }
    JSONObject *other = object;
    if (_storage.count != other->_storage.count) {
        return NO;
    }
    for (NSString *key in _storage) {
        JSONValue *value = _storage[key];
        JSONValue *otherValue = other->_storage[key];
        if (otherValue == nil || ![value isEqual:otherValue]) {
            return NO;
        }
    }
    return YES;
}

- (NSUInteger)hash {
    NSUInteger hash = _storage.count;
    for (NSString *key in _storage) {
        hash ^= key.hash;
    }
    return hash;
}

@end

@implementation JSONArray {
    NSMutableArray<JSONValue *> *_elements;
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _elements = [NSMutableArray array];
    }
    return self;
}

- (NSInteger)size {
    return (NSInteger)_elements.count;
}

- (JSONValue *)get:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_elements.count) {
        return nil;
    }
    return _elements[(NSUInteger)index];
}

- (NSString *)getString:(NSInteger)index {
    return [self get:index].string;
}

- (JSONObject *)getJSONObject:(NSInteger)index {
    return [self get:index].jsonObject;
}

- (void)add:(JSONValue *)value {
    [_elements addObject:value];
}

- (NSString *)description {
    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithCapacity:_elements.count];
    for (JSONValue *value in _elements) {
        [parts addObject:value.description];
    }
    return [NSString stringWithFormat:@"[%@]", [parts componentsJoinedByString:@", "]];
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[JSONArray class]]) {
        return NO;
    }
    JSONArray *other = object;
    return [_elements isEqualToArray:other->_elements];
}

- (NSUInteger)hash {
    return _elements.hash;
}

@end

@interface JSONReader ()
+ (JSONObject *)convertObject:(NSDictionary *)dictionary;
+ (JSONArray *)convertArray:(NSArray *)array;
+ (JSONValue *)convertValue:(id)value;
@end

@implementation JSONReader

+ (JSONObject *)rootObjectFromJSON:(NSString *)json
                     invalidPrefix:(NSString *)invalidPrefix
                         notObject:(NSString *)notObject
                             error:(NSError **)error {
    if (json == nil) {
        OTReject(error, [invalidPrefix stringByAppendingString:@"invalid UTF-8"]);
        return nil;
    }
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    if (data == nil) {
        OTReject(error, [invalidPrefix stringByAppendingString:@"invalid UTF-8"]);
        return nil;
    }
    NSError *parseError = nil;
    id raw = [NSJSONSerialization JSONObjectWithData:data
                                             options:NSJSONReadingFragmentsAllowed
                                               error:&parseError];
    if (raw == nil) {
        OTReject(error, [NSString stringWithFormat:@"%@%@", invalidPrefix, parseError.localizedDescription ?: @""]);
        return nil;
    }
    if (raw == [NSNull null]) {
        OTReject(error, notObject);
        return nil;
    }
    if (![raw isKindOfClass:[NSDictionary class]]) {
        OTReject(error, [invalidPrefix stringByAppendingString:@"can not cast to JSONObject."]);
        return nil;
    }
    return [self convertObject:raw];
}

+ (JSONObject *)requireObject:(JSONValue *)value path:(NSString *)path error:(NSError **)error {
    if (value.kind != JSONValueKindObject || value.jsonObject == nil) {
        OTReject(error, [NSString stringWithFormat:@"%@ 必须是对象", path]);
        return nil;
    }
    return value.jsonObject;
}

+ (JSONArray *)requireArray:(JSONValue *)value path:(NSString *)path error:(NSError **)error {
    if (value.kind != JSONValueKindArray || value.jsonArray == nil) {
        OTReject(error, [NSString stringWithFormat:@"%@ 必须是数组", path]);
        return nil;
    }
    return value.jsonArray;
}

+ (NSString *)requireString:(JSONValue *)value path:(NSString *)path error:(NSError **)error {
    if (value.kind != JSONValueKindString || value.string == nil) {
        OTReject(error, [NSString stringWithFormat:@"%@ 必须是字符串", path]);
        return nil;
    }
    return value.string;
}

+ (BOOL)requireKeys:(JSONObject *)node
               path:(NSString *)path
            allowed:(NSSet<NSString *> *)allowed
           required:(NSArray<NSString *> *)required
              error:(NSError **)error {
    for (NSString *key in node.keys) {
        if (![allowed containsObject:key]) {
            OTReject(error, [NSString stringWithFormat:@"%@.%@ 不是这里能写的字段", path, key]);
            return NO;
        }
    }
    for (NSString *key in required) {
        if (![node containsKey:key]) {
            OTReject(error, [NSString stringWithFormat:@"%@ 缺少 %@", path, key]);
            return NO;
        }
    }
    return YES;
}

+ (JSONObject *)convertObject:(NSDictionary *)dictionary {
    JSONObject *object = [[JSONObject alloc] init];
    for (id key in dictionary.allKeys) {
        if (![key isKindOfClass:[NSString class]]) {
            continue;
        }
        id value = [dictionary objectForKey:key];
        if (value != nil) {
            [object set:[self convertValue:value] forKey:key];
        }
    }
    return object;
}

+ (JSONArray *)convertArray:(NSArray *)array {
    JSONArray *result = [[JSONArray alloc] init];
    for (id value in array) {
        [result add:[self convertValue:value]];
    }
    return result;
}

+ (JSONValue *)convertValue:(id)value {
    if (value == nil || value == [NSNull null]) {
        return [JSONValue null];
    }
    if ([value isKindOfClass:[NSString class]]) {
        return [JSONValue string:value];
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        return [JSONValue object:[self convertObject:value]];
    }
    if ([value isKindOfClass:[NSArray class]]) {
        return [JSONValue array:[self convertArray:value]];
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *number = value;
        if (CFGetTypeID((__bridge CFTypeRef)number) == CFBooleanGetTypeID()) {
            return [JSONValue bool:number.boolValue];
        }
        if (CFNumberIsFloatType((__bridge CFNumberRef)number)) {
            return [JSONValue number:[JSONNumber doubleNumber:number.doubleValue]];
        }
        return [JSONValue number:[JSONNumber intNumber:number.longLongValue]];
    }
    return [JSONValue null];
}

@end
