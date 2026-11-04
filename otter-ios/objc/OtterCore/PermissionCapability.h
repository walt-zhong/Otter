#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PermissionCapability : NSObject
@property (class, nonatomic, readonly) NSString *CAMERA;
@property (class, nonatomic, readonly) NSString *MICROPHONE;
@property (class, nonatomic, readonly) NSString *LOCATION_WHEN_IN_USE;
@property (class, nonatomic, readonly) NSString *PHOTOS;
@property (class, nonatomic, readonly) NSString *NOTIFICATIONS;
@property (class, nonatomic, readonly) NSArray<NSString *> *all;
@end

@interface PermissionStatus : NSObject
@property (class, nonatomic, readonly) NSString *GRANTED;
@property (class, nonatomic, readonly) NSString *DENIED;
@property (class, nonatomic, readonly) NSString *LIMITED;
@property (class, nonatomic, readonly) NSString *PERMANENTLY_DENIED;
@property (class, nonatomic, readonly) NSString *RESTRICTED;
@property (class, nonatomic, readonly) NSString *UNSUPPORTED;
@end

NS_ASSUME_NONNULL_END
