#import "PermissionController.h"
#import "../OtterUI/Permission/OTPermissionCenter.h"

@implementation PermissionController {
    OTPermissionCenter *_permissions;
}

- (instancetype)init {
    self = [self initWithRoute:@"templates/permission/routes.json" bizId:@"demo" templateId:@"permission"];
    if (self) {
        self.chromeTitle = @"权限";
    }
    return self;
}

- (void)viewDidLoad {
    _permissions = [OTPermissionCenter installWithHost:self prompts:nil];
    [super viewDidLoad];
}

- (void)viewDidDisappear:(BOOL)animated {
    BOOL leaving = self.isMovingFromParentViewController || self.isBeingDismissed;
    if (leaving) {
        [_permissions releaseCenter];
        _permissions = nil;
    }
    [super viewDidDisappear:animated];
}

@end
