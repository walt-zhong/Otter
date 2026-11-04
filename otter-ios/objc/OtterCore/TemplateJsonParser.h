#import <Foundation/Foundation.h>
#import "JSONValue.h"

NS_ASSUME_NONNULL_BEGIN

@interface ParsedNode : NSObject
@property (nonatomic, copy, readonly) NSString *viewName;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *attrs;
@property (nonatomic, copy, readonly) NSArray<ParsedNode *> *children;
@property (nonatomic, strong, readonly, nullable) ParsedNode *item;
- (NSString *)id;
- (instancetype)initWithViewName:(NSString *)viewName
                              id:(NSString *)nodeId
                           attrs:(NSDictionary<NSString *, NSString *> *)attrs
                        children:(nullable NSArray<ParsedNode *> *)children
                            item:(nullable ParsedNode *)item;
@end

@interface ParsedTemplate : NSObject
@property (nonatomic, strong, readonly) ParsedNode *root;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, JSONObject *> *events;
- (instancetype)initWithRoot:(ParsedNode *)root
                      events:(NSDictionary<NSString *, JSONObject *> *)events;
@end

@interface TemplateJsonParser : NSObject
+ (nullable ParsedTemplate *)parseJSON:(NSString *)json error:(NSError * _Nullable * _Nullable)error;
@end

NS_ASSUME_NONNULL_END
