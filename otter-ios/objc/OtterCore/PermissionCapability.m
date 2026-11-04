#import "PermissionCapability.h"

@implementation PermissionCapability
+ (NSString *)CAMERA { return @"camera"; }
+ (NSString *)MICROPHONE { return @"microphone"; }
+ (NSString *)LOCATION_WHEN_IN_USE { return @"location.whenInUse"; }
+ (NSString *)PHOTOS { return @"photos"; }
+ (NSString *)NOTIFICATIONS { return @"notifications"; }
+ (NSArray<NSString *> *)all {
    return @[
        [self CAMERA],
        [self MICROPHONE],
        [self LOCATION_WHEN_IN_USE],
        [self PHOTOS],
        [self NOTIFICATIONS]
    ];
}
@end

@implementation PermissionStatus
+ (NSString *)GRANTED { return @"granted"; }
+ (NSString *)DENIED { return @"denied"; }
+ (NSString *)LIMITED { return @"limited"; }
+ (NSString *)PERMANENTLY_DENIED { return @"permanentlyDenied"; }
+ (NSString *)RESTRICTED { return @"restricted"; }
+ (NSString *)UNSUPPORTED { return @"unsupported"; }
@end
