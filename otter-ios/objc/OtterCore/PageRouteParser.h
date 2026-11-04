#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PageRoute : NSObject
@property (nonatomic, copy, readonly) NSString *template;
@property (nonatomic, copy, readonly, nullable) NSString *data;
- (instancetype)initWithTemplate:(NSString *)template data:(nullable NSString *)data;
@end

@interface PageRouteTable : NSObject
@property (nonatomic, copy, readonly) NSString *start;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, PageRoute *> *pages;
- (instancetype)initWithStart:(NSString *)start pages:(NSDictionary<NSString *, PageRoute *> *)pages;
@end

@interface PageRouteParser : NSObject
+ (nullable PageRouteTable *)parseJSON:(NSString *)json error:(NSError * _Nullable * _Nullable)error;
@end

NS_ASSUME_NONNULL_END
