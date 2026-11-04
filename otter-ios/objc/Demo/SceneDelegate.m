#import "SceneDelegate.h"
#import "MainController.h"

@implementation SceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:[MainController new]];
    navigation.navigationBarHidden = YES;
    window.rootViewController = navigation;
    window.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    self.window = window;
    [window makeKeyAndVisible];
}

@end
