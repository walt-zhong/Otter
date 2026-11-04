#import <UIKit/UIKit.h>
#import "../OTCore.h"

NS_ASSUME_NONNULL_BEGIN

@interface OTAssets : NSObject
@property (class, nonatomic, strong) NSBundle *bundle;
+ (nullable NSString *)text:(NSString *)path error:(NSError **)error;
+ (nullable NSURL *)file:(NSString *)path;
+ (nullable UIImage *)imageNamed:(NSString *)name;
@end

@interface OTMeasure : NSObject
+ (nullable NSNumber *)points:(nullable NSString *)raw scale:(CGFloat)scale;
@end

@interface OTColorParser : NSObject
+ (nullable UIColor *)color:(nullable NSString *)raw;
@end

@interface OTData : NSObject
+ (nullable JSONObject *)parseObject:(NSString *)json error:(NSError **)error;
+ (JSONObject *)objectFromDictionary:(NSDictionary *)dictionary;
+ (JSONValue *)valueFromAny:(nullable id)any;
+ (NSDictionary<NSString *, id> *)foundation:(nullable JSONObject *)object;
+ (nullable id)foundationValue:(nullable JSONValue *)value;
+ (nullable NSString *)text:(nullable JSONObject *)object;
+ (NSString *)display:(nullable id)value;
+ (BOOL)boolText:(nullable id)value;
+ (JSONObject *)evaluate:(JSONObject *)raw scope:(nullable JSONObject *)scope;
+ (JSONObject *)scopePage:(nullable JSONObject *)page item:(nullable JSONObject *)item;
+ (JSONArray *)listArray:(NSString *)expression data:(nullable JSONObject *)data;
+ (nullable JSONValue *)lookup:(NSString *)path data:(nullable JSONObject *)data;
+ (nullable JSONObject *)deepCopy:(nullable JSONObject *)object;
+ (void)setValue:(nullable JSONValue *)value forKey:(NSString *)key on:(JSONObject *)object;
+ (NSInteger)intValue:(JSONObject *)object key:(NSString *)key;
@end

@interface OTLayoutCall : NSObject
+ (nullable OTLaidOutNode *)layoutRoot:(ParsedNode *)root
                                  data:(nullable JSONObject *)data
                              viewport:(CGSize)viewport
                           windowWidth:(CGFloat)windowWidth
                                 error:(NSError **)error;
@end

@interface OTFont : NSObject
+ (UIFont *)fontForFields:(NSDictionary<NSString *, NSString *> *)fields scale:(CGFloat)scale;
@end

NSError *OTParseError(NSString *message);

NS_ASSUME_NONNULL_END
