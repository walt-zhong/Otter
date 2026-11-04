#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PageFrames : NSObject
@property (nonatomic, readonly) NSInteger depth;
- (void)push:(NSString *)name;
- (nullable NSString *)pop;
- (nullable NSString *)drop;
- (nullable NSArray<NSString *> *)popTo:(NSString *)name;
- (nullable NSString *)top;
- (NSArray<NSString *> *)clear;
@end

NS_ASSUME_NONNULL_END
