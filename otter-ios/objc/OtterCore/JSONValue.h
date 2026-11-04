#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const TemplateParseExceptionDomain;
FOUNDATION_EXPORT NSError *TemplateParseExceptionError(NSString *message);

typedef NS_ENUM(NSInteger, JSONValueKind) {
    JSONValueKindObject,
    JSONValueKindArray,
    JSONValueKindString,
    JSONValueKindNumber,
    JSONValueKindBool,
    JSONValueKindNull,
};

@interface JSONNumber : NSObject
@property (nonatomic, readonly) BOOL isDouble;
@property (nonatomic, readonly) int64_t intValue;
@property (nonatomic, readonly) double doubleValue;
+ (instancetype)intNumber:(int64_t)value;
+ (instancetype)doubleNumber:(double)value;
@end

@class JSONObject;
@class JSONArray;

@interface JSONValue : NSObject
@property (nonatomic, readonly) JSONValueKind kind;
@property (nonatomic, readonly, nullable) NSString *string;
@property (nonatomic, readonly, nullable) JSONObject *jsonObject;
@property (nonatomic, readonly, nullable) JSONArray *jsonArray;
@property (nonatomic, readonly, nullable) JSONNumber *number;
@property (nonatomic, readonly) BOOL boolValue;
+ (instancetype)object:(JSONObject *)object;
+ (instancetype)array:(JSONArray *)array;
+ (instancetype)string:(NSString *)string;
+ (instancetype)number:(JSONNumber *)number;
+ (instancetype)bool:(BOOL)value;
+ (instancetype)null;
@end

@interface JSONObject : NSObject
@property (nonatomic, readonly) NSInteger size;
@property (nonatomic, readonly) BOOL isEmpty;
@property (nonatomic, readonly) NSArray<NSString *> *keys;
- (BOOL)containsKey:(NSString *)key;
- (nullable JSONValue *)get:(NSString *)key;
- (nullable NSString *)getString:(NSString *)key;
- (nullable JSONObject *)getJSONObject:(NSString *)key;
- (nullable JSONArray *)getJSONArray:(NSString *)key;
- (BOOL)getBooleanValue:(NSString *)key;
- (void)set:(nullable JSONValue *)value forKey:(NSString *)key;
- (nullable JSONValue *)objectForKeyedSubscript:(NSString *)key;
- (void)setObject:(nullable JSONValue *)object forKeyedSubscript:(NSString *)key;
@end

@interface JSONArray : NSObject
@property (nonatomic, readonly) NSInteger size;
- (nullable JSONValue *)get:(NSInteger)index;
- (nullable NSString *)getString:(NSInteger)index;
- (nullable JSONObject *)getJSONObject:(NSInteger)index;
- (void)add:(JSONValue *)value;
@end

@interface JSONReader : NSObject
+ (nullable JSONObject *)rootObjectFromJSON:(NSString *)json
                              invalidPrefix:(NSString *)invalidPrefix
                                  notObject:(NSString *)notObject
                                      error:(NSError * _Nullable * _Nullable)error;
+ (nullable JSONObject *)requireObject:(nullable JSONValue *)value
                                  path:(NSString *)path
                                 error:(NSError * _Nullable * _Nullable)error;
+ (nullable JSONArray *)requireArray:(nullable JSONValue *)value
                                path:(NSString *)path
                               error:(NSError * _Nullable * _Nullable)error;
+ (nullable NSString *)requireString:(nullable JSONValue *)value
                                path:(NSString *)path
                               error:(NSError * _Nullable * _Nullable)error;
+ (BOOL)requireKeys:(JSONObject *)node
               path:(NSString *)path
            allowed:(NSSet<NSString *> *)allowed
           required:(NSArray<NSString *> *)required
              error:(NSError * _Nullable * _Nullable)error;
@end

NS_ASSUME_NONNULL_END
