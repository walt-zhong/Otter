#import <Foundation/Foundation.h>
#import "JSONValue.h"

NS_ASSUME_NONNULL_BEGIN

typedef JSONValue * _Nullable (^PageParamsResolver)(NSString *expression);

@interface JSONText : NSObject
+ (BOOL)isName:(NSString *)text;
+ (BOOL)isHexColor:(NSString *)text;
@end

@interface PageParams : NSObject
+ (JSONObject *)evaluate:(JSONObject *)raw resolver:(PageParamsResolver)resolver;
+ (BOOL)matches:(nullable JSONObject *)data overlay:(nullable JSONObject *)overlay;
+ (void)mergeInto:(JSONObject *)target overlay:(JSONObject *)overlay;
+ (BOOL)findItemInPage:(nullable JSONObject *)page
                  item:(nullable JSONObject *)item
                   key:(NSString * _Nullable * _Nullable)key
                 index:(NSInteger * _Nullable)index;
+ (nullable JSONObject *)merge:(nullable JSONObject *)base overlay:(nullable JSONObject *)overlay;
@end

NS_ASSUME_NONNULL_END
