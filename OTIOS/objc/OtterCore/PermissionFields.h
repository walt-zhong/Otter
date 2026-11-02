#import <Foundation/Foundation.h>
#import "JSONValue.h"
#import "PermissionResult.h"

NS_ASSUME_NONNULL_BEGIN

@interface PermissionFields : NSObject
+ (nullable NSString *)prefixForCapability:(NSString *)capability;
+ (void)write:(JSONObject *)data result:(PermissionResult *)result;
+ (PermissionResult *)preservingPhoto:(JSONObject *)data result:(PermissionResult *)result;
@end

NS_ASSUME_NONNULL_END
