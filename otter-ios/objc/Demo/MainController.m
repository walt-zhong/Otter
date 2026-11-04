#import "MainController.h"
#import "DemoRoutes.h"
#import "TemplateScreen.h"
#import "../OtterUI/Engine/ExpansionCenter.h"

@implementation MainController {
    UIView *_container;
    TemplateScreen *_screen;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = DemoPageColor();
    DemoTopBar *bar = [DemoTopBar barWithTitle:@"Otter" showsBack:NO];
    [self.view addSubview:bar];
    _container = [UIView new];
    [self.view addSubview:_container];
    [ExpansionCenter.shared registerPageOpener:^(UIViewController *controller, NSString *page) {
        [DemoRoutes open:controller page:page];
    }];
    _screen = [[TemplateScreen alloc] initWithController:self
                                               container:_container
                                            templatePath:@"templates/home-demo/home.json"
                                                dataPath:@"templates/home-demo/mock-data/home.json"
                                                 onReady:nil];
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

@end
