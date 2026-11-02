#import "WeatherCardController.h"
#import "DemoRoutes.h"
#import "TemplateScreen.h"

@implementation WeatherCardController {
    UIView *_container;
    TemplateScreen *_screen;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = DemoPageColor();
    DemoTopBar *bar = [DemoTopBar barWithTitle:@"天气" showsBack:YES];
    __weak WeatherCardController *barOwner = self;
    bar.onBack = ^{
        [DemoRoutes goBack:barOwner];
    };
    [self.view addSubview:bar];
    _container = [UIView new];
    [self.view addSubview:_container];
    _screen = [[TemplateScreen alloc] initWithController:self
                                               container:_container
                                            templatePath:@"templates/weather-card-demo/weather-card.json"
                                                dataPath:@"templates/weather-card-demo/mock-data/weather-card.json"
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
