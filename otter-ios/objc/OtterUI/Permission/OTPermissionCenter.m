#import "OTPermissionCenter.h"
#import "../Engine/ExpansionCenter.h"
#import "../Nav/PageStack.h"
#import "../Render/OTNodes.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <PhotosUI/PhotosUI.h>
#import <UserNotifications/UserNotifications.h>

static NSMapTable<UIViewController *, OTPermissionCenter *> *OTPermissionInstalled(void) {
    static NSMapTable *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = [NSMapTable weakToStrongObjectsMapTable];
    });
    return table;
}

@interface OTPermissionCenter () <CLLocationManagerDelegate, PHPickerViewControllerDelegate>
@end

@implementation OTPermissionCenter {
    __weak UIViewController *_host;
    NSDictionary<NSString *, PermissionPrompt *> *_prompts;
    BOOL _released;
    BOOL _inFlight;
    void (^_pending)(PermissionResult *);
    NSString *_pendingCapability;
    CLLocationManager *_location;
    BOOL _locationAsked;
    PermissionResult *_notificationCache;
}

+ (OTPermissionCenter *)installWithHost:(UIViewController *)host prompts:(NSDictionary<NSString *, PermissionPrompt *> *)prompts {
    OTPermissionCenter *existing = [OTPermissionInstalled() objectForKey:host];
    if (existing && !existing->_released) {
        return existing;
    }
    NSDictionary *resolved = prompts ?: [PermissionPrompts standard];
    OTPermissionCenter *created = [[OTPermissionCenter alloc] initWithHost:host prompts:resolved];
    [OTPermissionInstalled() setObject:created forKey:host];
    [created registerActions];
    return created;
}

+ (OTPermissionCenter *)find:(UIView *)view {
    UIViewController *host = view.ot_controller;
    if (!host) {
        return nil;
    }
    OTPermissionCenter *center = [OTPermissionInstalled() objectForKey:host];
    if (center.released) {
        return nil;
    }
    return center;
}

- (instancetype)initWithHost:(UIViewController *)host prompts:(NSDictionary<NSString *, PermissionPrompt *> *)prompts {
    self = [super init];
    if (self) {
        _host = host;
        _prompts = [prompts copy];
        _location = [CLLocationManager new];
        _location.delegate = self;
        _notificationCache = [PermissionJudge notificationsWithRequiresRuntime:YES granted:NO asked:NO shouldShowRationale:YES];
        [self refreshNotifications];
    }
    return self;
}

- (BOOL)released {
    return _released;
}

- (void)releaseCenter {
    _location.delegate = nil;
    _released = YES;
    _pending = nil;
    _inFlight = NO;
    if (_host) {
        [OTPermissionInstalled() removeObjectForKey:_host];
    }
}

- (void)registerActions {
    ExpansionCenter *center = ExpansionCenter.shared;
    [center registerHostAction:PermissionActions.CHECK action:^(UIView *view, JSONObject *params) {
        [OTPermissionCenter dispatch:view params:params mode:0];
    }];
    [center registerHostAction:PermissionActions.REQUEST action:^(UIView *view, JSONObject *params) {
        [OTPermissionCenter dispatch:view params:params mode:1];
    }];
    [center registerHostAction:PermissionActions.OPEN_SETTINGS action:^(UIView *view, JSONObject *params) {
        [OTPermissionCenter dispatch:view params:params mode:2];
    }];
}

+ (void)dispatch:(UIView *)view params:(JSONObject *)params mode:(NSInteger)mode {
    NSString *capability = [params getString:@"capability"] ?: @"";
    if (capability.length == 0 || ![PermissionFields prefixForCapability:capability]) {
        [OTToast show:@"没有这项能力" inView:view];
        return;
    }
    OTPermissionCenter *center = [self find:view];
    if (!center) {
        [OTToast show:@"这个操作还不能用" inView:view];
        return;
    }
    [center one:view params:params mode:mode];
}

- (void)publishAll:(UIView *)view {
    PageStack *stack = [PageStack find:view];
    if (!stack) {
        return;
    }
    NSMutableArray<PermissionResult *> *results = [NSMutableArray array];
    for (NSString *capability in PermissionCapability.all) {
        [results addObject:[self check:capability]];
    }
    [stack editCurrentData:^(JSONObject *data) {
        for (PermissionResult *result in results) {
            [PermissionFields write:data result:[PermissionFields preservingPhoto:data result:result]];
        }
    }];
    [stack rebindCurrent];
}

- (void)one:(UIView *)view params:(JSONObject *)params mode:(NSInteger)mode {
    NSString *capability = [params getString:@"capability"] ?: @"";
    if (capability.length == 0 || ![PermissionFields prefixForCapability:capability]) {
        [OTToast show:@"没有这项能力" inView:view];
        return;
    }
    if (![OTPermissionCenter find:view]) {
        [OTToast show:@"这个操作还不能用" inView:view];
        return;
    }
    if (mode == 0) {
        [self publish:view result:[self check:capability]];
    } else if (mode == 1) {
        __weak OTPermissionCenter *weakSelf = self;
        [self request:capability onResult:^(PermissionResult *result) {
            [weakSelf publish:view result:result];
        }];
    } else {
        __weak OTPermissionCenter *weakSelf = self;
        [self openSettings:capability onResult:^(PermissionResult *result) {
            [weakSelf publish:view result:result];
        }];
    }
}

- (void)publish:(UIView *)view result:(PermissionResult *)result {
    PageStack *stack = [PageStack find:view];
    if (!stack) {
        [OTToast show:@"这个页面还接不上" inView:view];
        return;
    }
    [stack editCurrentData:^(JSONObject *data) {
        [PermissionFields write:data result:[PermissionFields preservingPhoto:data result:result]];
    }];
    [stack rebindCurrent];
}

- (PermissionResult *)check:(NSString *)capability {
    if ([capability isEqualToString:PermissionCapability.PHOTOS]) {
        return [PermissionJudge photosAsked:[self asked:capability]];
    }
    if (![PermissionCapability.all containsObject:capability] || ![self hardware:capability]) {
        return [PermissionJudge unsupported:capability];
    }
    if ([capability isEqualToString:PermissionCapability.CAMERA]) {
        return [self singleStatus:capability status:[AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]];
    }
    if ([capability isEqualToString:PermissionCapability.MICROPHONE]) {
        return [self microphoneStatus];
    }
    if ([capability isEqualToString:PermissionCapability.LOCATION_WHEN_IN_USE]) {
        return [self locationStatus];
    }
    if ([capability isEqualToString:PermissionCapability.NOTIFICATIONS]) {
        return [self notificationStatus];
    }
    return [PermissionJudge unsupported:capability];
}

- (void)request:(NSString *)capability onResult:(void (^)(PermissionResult *))onResult {
    if (_inFlight || _released || !onResult) {
        return;
    }
    PermissionResult *current = [self check:capability];
    if (![self shouldPrompt:current]) {
        onResult(current);
        return;
    }
    PermissionPrompt *prompt = _prompts[capability] ?: [[PermissionPrompt alloc] initWithTitle:@"权限" message:@"接下来会弹出系统对话框，你可以拒绝。"];
    _inFlight = YES;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:prompt.title message:prompt.message preferredStyle:UIAlertControllerStyleAlert];
    __weak OTPermissionCenter *weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"继续" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf launch:capability onResult:onResult];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"先不用" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        weakSelf.inFlight = NO;
    }]];
    [_host presentViewController:alert animated:YES completion:nil];
}

- (void)setInFlight:(BOOL)inFlight {
    _inFlight = inFlight;
}

- (void)openSettings:(NSString *)capability onResult:(void (^)(PermissionResult *))onResult {
    if (_inFlight || _released || !onResult) {
        return;
    }
    _inFlight = YES;
    _pending = [onResult copy];
    _pendingCapability = capability;
    [self markAsked:capability];
    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if (!url) {
        [self finish:[self check:capability]];
        return;
    }
    __weak OTPermissionCenter *weakSelf = self;
    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            OTPermissionCenter *self = weakSelf;
            if (!self) {
                return;
            }
            [self finish:[self check:capability]];
        });
    }];
}

- (void)launch:(NSString *)capability onResult:(void (^)(PermissionResult *))onResult {
    _pending = [onResult copy];
    _pendingCapability = capability;
    if ([capability isEqualToString:PermissionCapability.PHOTOS]) {
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
        config.filter = PHPickerFilter.imagesFilter;
        config.selectionLimit = 1;
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
        picker.delegate = self;
        [_host presentViewController:picker animated:YES completion:nil];
        return;
    }
    if ([capability isEqualToString:PermissionCapability.CAMERA]) {
        __weak OTPermissionCenter *weakSelf = self;
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf markAsked:capability];
                [weakSelf finish:[weakSelf check:capability] ?: [PermissionJudge unsupported:capability]];
            });
        }];
        return;
    }
    if ([capability isEqualToString:PermissionCapability.MICROPHONE]) {
        __weak OTPermissionCenter *weakSelf = self;
        [AVAudioSession.sharedInstance requestRecordPermission:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf markAsked:capability];
                [weakSelf finish:[weakSelf check:capability] ?: [PermissionJudge unsupported:capability]];
            });
        }];
        return;
    }
    if ([capability isEqualToString:PermissionCapability.LOCATION_WHEN_IN_USE]) {
        _locationAsked = YES;
        [self markAsked:capability];
        [_location requestWhenInUseAuthorization];
        return;
    }
    if ([capability isEqualToString:PermissionCapability.NOTIFICATIONS]) {
        __weak OTPermissionCenter *weakSelf = self;
        [UNUserNotificationCenter.currentNotificationCenter requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge) completionHandler:^(BOOL granted, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf markAsked:capability];
                [weakSelf finish:[weakSelf check:capability] ?: [PermissionJudge unsupported:capability]];
            });
        }];
        return;
    }
    [self finish:[self check:capability]];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    [self markAsked:PermissionCapability.PHOTOS];
    NSItemProvider *provider = results.firstObject.itemProvider;
    if (![provider canLoadObjectOfClass:[UIImage class]]) {
        [self finish:[PermissionJudge photosAsked:YES]];
        return;
    }
    __weak OTPermissionCenter *weakSelf = self;
    [provider loadObjectOfClass:[UIImage class] completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            OTPermissionCenter *self = weakSelf;
            if (!self) {
                return;
            }
            UIImage *image = [object isKindOfClass:[UIImage class]] ? (UIImage *)object : nil;
            NSData *data = image ? UIImageJPEGRepresentation(image, 0.9) : nil;
            if (!data) {
                [self finish:[PermissionJudge photosAsked:YES]];
                return;
            }
            NSURL *url = [NSFileManager.defaultManager.temporaryDirectory URLByAppendingPathComponent:[NSString stringWithFormat:@"otter-photo-%@.jpg", NSUUID.UUID.UUIDString]];
            if ([data writeToURL:url options:NSDataWritingAtomic error:nil]) {
                [self finish:[PermissionJudge grantedPhoto:[NSString stringWithFormat:@"content:%@", url.path]]];
            } else {
                [self finish:[PermissionJudge photosAsked:YES]];
            }
        });
    }];
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    if (!_locationAsked && ![_pendingCapability isEqualToString:PermissionCapability.LOCATION_WHEN_IN_USE]) {
        return;
    }
    [self markAsked:PermissionCapability.LOCATION_WHEN_IN_USE];
    [self finish:[self check:PermissionCapability.LOCATION_WHEN_IN_USE]];
}

- (void)finish:(PermissionResult *)result {
    void (^callback)(PermissionResult *) = _pending;
    _pending = nil;
    _pendingCapability = nil;
    _inFlight = NO;
    _locationAsked = NO;
    if (callback && result) {
        callback(result);
    }
}

- (BOOL)shouldPrompt:(PermissionResult *)current {
    if ([current.status isEqualToString:PermissionStatus.UNSUPPORTED] ||
        [current.status isEqualToString:PermissionStatus.RESTRICTED] ||
        [current.status isEqualToString:PermissionStatus.GRANTED] ||
        [current.status isEqualToString:PermissionStatus.PERMANENTLY_DENIED]) {
        return NO;
    }
    if ([current.status isEqualToString:PermissionStatus.LIMITED] && !current.canAskAgain) {
        return NO;
    }
    return current.canAskAgain;
}

- (PermissionResult *)singleStatus:(NSString *)capability status:(AVAuthorizationStatus)status {
    switch (status) {
        case AVAuthorizationStatusAuthorized:
            return [PermissionJudge single:capability granted:YES asked:[self asked:capability] shouldShowRationale:NO];
        case AVAuthorizationStatusNotDetermined:
            return [PermissionJudge single:capability granted:NO asked:NO shouldShowRationale:YES];
        case AVAuthorizationStatusRestricted:
            return [[PermissionResult alloc] initWithCapability:capability status:PermissionStatus.RESTRICTED canAskAgain:NO asked:[self asked:capability] detail:nil];
        case AVAuthorizationStatusDenied:
            return [PermissionJudge single:capability granted:NO asked:YES shouldShowRationale:NO];
        default:
            return [PermissionJudge unsupported:capability];
    }
}

- (PermissionResult *)microphoneStatus {
    switch (AVAudioSession.sharedInstance.recordPermission) {
        case AVAudioSessionRecordPermissionGranted:
            return [PermissionJudge single:PermissionCapability.MICROPHONE granted:YES asked:[self asked:PermissionCapability.MICROPHONE] shouldShowRationale:NO];
        case AVAudioSessionRecordPermissionUndetermined:
            return [PermissionJudge single:PermissionCapability.MICROPHONE granted:NO asked:NO shouldShowRationale:YES];
        case AVAudioSessionRecordPermissionDenied:
            return [PermissionJudge single:PermissionCapability.MICROPHONE granted:NO asked:YES shouldShowRationale:NO];
        default:
            return [PermissionJudge unsupported:PermissionCapability.MICROPHONE];
    }
}

- (PermissionResult *)locationStatus {
    if (![CLLocationManager locationServicesEnabled]) {
        return [PermissionJudge unsupported:PermissionCapability.LOCATION_WHEN_IN_USE];
    }
    switch (_location.authorizationStatus) {
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse: {
            BOOL precise = _location.accuracyAuthorization == CLAccuracyAuthorizationFullAccuracy;
            return [PermissionJudge locationWithFineGranted:precise coarseGranted:!precise asked:[self asked:PermissionCapability.LOCATION_WHEN_IN_USE] fineShouldShow:NO coarseShouldShow:NO];
        }
        case kCLAuthorizationStatusNotDetermined:
            return [PermissionJudge single:PermissionCapability.LOCATION_WHEN_IN_USE granted:NO asked:NO shouldShowRationale:YES];
        case kCLAuthorizationStatusRestricted:
            return [[PermissionResult alloc] initWithCapability:PermissionCapability.LOCATION_WHEN_IN_USE status:PermissionStatus.RESTRICTED canAskAgain:NO asked:[self asked:PermissionCapability.LOCATION_WHEN_IN_USE] detail:nil];
        case kCLAuthorizationStatusDenied:
            return [PermissionJudge single:PermissionCapability.LOCATION_WHEN_IN_USE granted:NO asked:YES shouldShowRationale:NO];
        default:
            return [PermissionJudge unsupported:PermissionCapability.LOCATION_WHEN_IN_USE];
    }
}

- (PermissionResult *)notificationStatus {
    [self refreshNotifications];
    return _notificationCache;
}

- (void)refreshNotifications {
    __weak OTPermissionCenter *weakSelf = self;
    [UNUserNotificationCenter.currentNotificationCenter getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        OTPermissionCenter *self = weakSelf;
        if (!self) {
            return;
        }
        BOOL asked = [self asked:PermissionCapability.NOTIFICATIONS];
        PermissionResult *next = nil;
        switch (settings.authorizationStatus) {
            case UNAuthorizationStatusAuthorized:
            case UNAuthorizationStatusProvisional:
            case UNAuthorizationStatusEphemeral:
                next = [PermissionJudge notificationsWithRequiresRuntime:YES granted:YES asked:asked shouldShowRationale:NO];
                break;
            case UNAuthorizationStatusNotDetermined:
                next = [PermissionJudge notificationsWithRequiresRuntime:YES granted:NO asked:NO shouldShowRationale:YES];
                break;
            case UNAuthorizationStatusDenied:
                next = [PermissionJudge notificationsWithRequiresRuntime:YES granted:NO asked:YES shouldShowRationale:NO];
                break;
            default:
                next = [PermissionJudge unsupported:PermissionCapability.NOTIFICATIONS];
                break;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_notificationCache = next;
        });
    }];
}

- (BOOL)hardware:(NSString *)capability {
    if ([capability isEqualToString:PermissionCapability.CAMERA]) {
        return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] != nil;
    }
    if ([capability isEqualToString:PermissionCapability.MICROPHONE]) {
        return AVAudioSession.sharedInstance.isInputAvailable;
    }
    if ([capability isEqualToString:PermissionCapability.LOCATION_WHEN_IN_USE]) {
        return [CLLocationManager locationServicesEnabled];
    }
    return YES;
}

- (BOOL)asked:(NSString *)capability {
    return [NSUserDefaults.standardUserDefaults boolForKey:[NSString stringWithFormat:@"otter.permission.%@", capability]];
}

- (void)markAsked:(NSString *)capability {
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:[NSString stringWithFormat:@"otter.permission.%@", capability]];
}

@end
