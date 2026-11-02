#import "PermissionFields.h"
#import "PermissionCapability.h"

@implementation PermissionFields

+ (NSString *)prefixForCapability:(NSString *)capability {
    if ([capability isEqualToString:[PermissionCapability CAMERA]]) {
        return @"camera";
    }
    if ([capability isEqualToString:[PermissionCapability MICROPHONE]]) {
        return @"microphone";
    }
    if ([capability isEqualToString:[PermissionCapability LOCATION_WHEN_IN_USE]]) {
        return @"location";
    }
    if ([capability isEqualToString:[PermissionCapability PHOTOS]]) {
        return @"photos";
    }
    if ([capability isEqualToString:[PermissionCapability NOTIFICATIONS]]) {
        return @"notifications";
    }
    return nil;
}

+ (void)write:(JSONObject *)data result:(PermissionResult *)result {
    NSString *key = [self prefixForCapability:result.capability];
    if (key == nil) {
        return;
    }
    [data set:[JSONValue string:result.status] forKey:[key stringByAppendingString:@"Status"]];
    [data set:[JSONValue string:[result statusText]] forKey:[key stringByAppendingString:@"StatusText"]];
    [data set:[JSONValue bool:result.showSettings] forKey:[key stringByAppendingString:@"ShowSettings"]];
    if (![result.capability isEqualToString:[PermissionCapability PHOTOS]]) {
        return;
    }
    if ([result.status isEqualToString:[PermissionStatus GRANTED]] && [result.detail hasPrefix:@"content:"]) {
        [data set:[JSONValue string:result.detail] forKey:@"photoSrc"];
        [data set:[JSONValue string:result.detail] forKey:@"avatar"];
        [data set:[JSONValue bool:YES] forKey:@"photoVisible"];
    }
}

+ (PermissionResult *)preservingPhoto:(JSONObject *)data result:(PermissionResult *)result {
    if (![result.capability isEqualToString:[PermissionCapability PHOTOS]]) {
        return result;
    }
    if ([result.status isEqualToString:[PermissionStatus GRANTED]] && [result.detail hasPrefix:@"content:"]) {
        return result;
    }
    NSArray *candidates = @[
        [data getString:@"photoSrc"] ?: (id)[NSNull null],
        [data getString:@"avatar"] ?: (id)[NSNull null]
    ];
    NSString *saved = nil;
    for (id candidate in candidates) {
        if (![candidate isKindOfClass:[NSString class]]) {
            continue;
        }
        NSString *value = candidate;
        NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length > 0 && [value hasPrefix:@"content:"]) {
            saved = value;
            break;
        }
    }
    if (saved == nil) {
        return result;
    }
    return [[PermissionResult alloc] initWithCapability:result.capability
                                                  status:[PermissionStatus GRANTED]
                                             canAskAgain:YES
                                                   asked:YES
                                                  detail:saved];
}

@end
