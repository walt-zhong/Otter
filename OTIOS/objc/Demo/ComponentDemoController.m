#import "ComponentDemoController.h"
#import "DemoRoutes.h"
#import "PlayerSession.h"
#import "TemplateScreen.h"

@implementation ComponentDemoController {
    NSString *_templatePath;
    NSString *_dataPath;
    NSString *_title;
    UIView *_container;
    TemplateScreen *_screen;
    PlayerSession *_player;
}

- (instancetype)initWithTemplatePath:(NSString *)templatePath dataPath:(NSString *)dataPath title:(NSString *)title {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _templatePath = [templatePath copy];
        _dataPath = [dataPath copy];
        _title = [title copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (_templatePath.length == 0 || _dataPath.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.navigationController.topViewController == self) {
                [self.navigationController popViewControllerAnimated:NO];
            } else if (self.presentingViewController) {
                [self dismissViewControllerAnimated:NO completion:nil];
            }
        });
        return;
    }
    self.view.backgroundColor = DemoPageColor();
    DemoTopBar *bar = [DemoTopBar barWithTitle:_title ?: @"" showsBack:YES];
    __weak ComponentDemoController *barOwner = self;
    bar.onBack = ^{
        [DemoRoutes goBack:barOwner];
    };
    [self.view addSubview:bar];
    _container = [UIView new];
    [self.view addSubview:_container];
    __weak ComponentDemoController *weakSelf = self;
    _screen = [[TemplateScreen alloc] initWithController:self container:_container templatePath:_templatePath dataPath:_dataPath onReady:^(UIView *root) {
        ComponentDemoController *controller = weakSelf;
        if (controller && [controller->_templatePath hasSuffix:@"templates/player/player.json"]) {
            controller->_player = [PlayerSession attach:root];
        }
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    [_screen noteSafeArea];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [_screen noteLayout];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [_screen noteAppear];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.isMovingFromParentViewController || self.isBeingDismissed) {
        [_player releaseSession];
        _player = nil;
    }
}

@end
