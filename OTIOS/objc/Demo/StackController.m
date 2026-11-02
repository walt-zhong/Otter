#import "StackController.h"
#import "DemoRoutes.h"
#import "../OtterUI/Engine/OTBridge.h"
#import "../OtterUI/Nav/PageStack.h"
#import "../OtterUI/Render/OTNodes.h"

@implementation StackController {
    UIView *_container;
    PageStack *_stack;
    NSString *_pendingState;
}

- (instancetype)initWithRoute:(NSString *)route bizId:(NSString *)bizId templateId:(NSString *)templateId {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _route = [route copy];
        _bizId = [bizId copy];
        _templateId = [templateId copy];
        _chromeTitle = @"城南";
        self.restorationIdentifier = [NSString stringWithFormat:@"otter.stack.%@", templateId];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = DemoPageColor();
    DemoTopBar *bar = [DemoTopBar barWithTitle:self.chromeTitle ?: @"城南" showsBack:YES];
    __weak StackController *barOwner = self;
    bar.onBack = ^{
        [DemoRoutes goBack:barOwner];
    };
    [self.view addSubview:bar];
    _container = [UIView new];
    [self.view addSubview:_container];
    [OTIme installOn:self.view];
    NSError *error = nil;
    PageStack *attached = [PageStack attachWithHost:self insetRoot:self.view container:_container routePath:self.route bizId:self.bizId templateId:self.templateId error:&error];
    if (!attached) {
        [OTToast show:error.localizedDescription ?: @"这个页面还打不开" inView:self.view];
    } else if (_pendingState) {
        [attached restoreState:_pendingState];
    }
    _stack = attached;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    DemoTopBar *bar = nil;
    for (UIView *child in self.view.subviews) {
        if ([child isKindOfClass:[DemoTopBar class]]) {
            bar = (DemoTopBar *)child;
            break;
        }
    }
    UIEdgeInsets safe = self.view.safeAreaInsets;
    CGFloat width = self.view.bounds.size.width;
    CGFloat barHeight = bar ? [DemoTopBar barHeight] : 0;
    if (bar) {
        bar.frame = CGRectMake(safe.left, safe.top, MAX(width - safe.left - safe.right, 0), barHeight);
        [self.view bringSubviewToFront:bar];
    }
    CGFloat top = safe.top + barHeight;
    _container.frame = CGRectMake(safe.left, top, MAX(width - safe.left - safe.right, 0), MAX(self.view.bounds.size.height - top - safe.bottom, 0));
    [_stack layoutContainers];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [_stack activate];
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
    [super encodeRestorableStateWithCoder:coder];
    NSString *text = [_stack exportState];
    if (text) {
        [coder encodeObject:text forKey:@"otter.pages"];
    }
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder {
    [super decodeRestorableStateWithCoder:coder];
    NSString *text = [coder decodeObjectOfClass:[NSString class] forKey:@"otter.pages"];
    if (_stack) {
        [_stack restoreState:text];
    } else {
        _pendingState = text;
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.isMovingFromParentViewController || self.isBeingDismissed) {
        [_stack releaseStack];
        _stack = nil;
    }
}

@end
