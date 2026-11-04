#import "PermissionPrompts.h"
#import "PermissionCapability.h"

@implementation PermissionPrompts

+ (NSDictionary<NSString *, PermissionPrompt *> *)standard {
    return @{
        [PermissionCapability CAMERA]: [[PermissionPrompt alloc] initWithTitle:@"相机"
                                                                        message:@"用来拍照。接下来会弹出系统对话框，你可以拒绝。"],
        [PermissionCapability MICROPHONE]: [[PermissionPrompt alloc] initWithTitle:@"麦克风"
                                                                            message:@"用来录音。接下来会弹出系统对话框，你可以拒绝。"],
        [PermissionCapability LOCATION_WHEN_IN_USE]: [[PermissionPrompt alloc] initWithTitle:@"位置"
                                                                                      message:@"只在使用时获取位置，不会在后台定位。你可以只给大致位置。"],
        [PermissionCapability PHOTOS]: [[PermissionPrompt alloc] initWithTitle:@"相册"
                                                                        message:@"接下来打开系统选图。只会拿到你选中的那张，不会读取整个相册。"],
        [PermissionCapability NOTIFICATIONS]: [[PermissionPrompt alloc] initWithTitle:@"通知"
                                                                               message:@"用来发送通知。接下来会弹出系统对话框，你可以拒绝。"]
    };
}

@end
