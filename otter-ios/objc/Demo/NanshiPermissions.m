#import "NanshiPermissions.h"

@implementation NanshiPermissions

+ (NSDictionary<NSString *, PermissionPrompt *> *)prompts {
    return @{
        PermissionCapability.CAMERA: [[PermissionPrompt alloc] initWithTitle:@"拍菜单" message:@"南市想用相机，拍下黑板上的字。这次只确认允不允许，还不会打开相机。"],
        PermissionCapability.MICROPHONE: [[PermissionPrompt alloc] initWithTitle:@"留一句" message:@"南市想用麦克风，留一句给店员。这次只确认允不允许，还不会录音。"],
        PermissionCapability.LOCATION_WHEN_IN_USE: [[PermissionPrompt alloc] initWithTitle:@"走到巷口" message:@"只在你查看南市时使用位置，用来判断你在不在这条巷。不会在后台定位。你可以只给大致位置。"],
        PermissionCapability.PHOTOS: [[PermissionPrompt alloc] initWithTitle:@"换头像" message:@"从相册选一张做头像。只会拿到你点中的那张，不会读取整个相册。"],
        PermissionCapability.NOTIFICATIONS: [[PermissionPrompt alloc] initWithTitle:@"取餐通知" message:@"摊位做好了就通知你。接下来会弹出系统对话框，你可以拒绝。"]
    };
}

@end
