#import "TemplateScreen.h"
#import "DemoRoutes.h"
#import "../OtterUI/Engine/OTEngine.h"
#import "../OtterUI/Engine/OTBridge.h"
#import "../OtterUI/Render/OTNodes.h"

@implementation TemplateScreen {
    __weak UIViewController *_controller;
    UIView *_container;
    NSString *_templatePath;
    NSString *_dataPath;
    void (^_onReady)(UIView *);
    BOOL _insetsApplied;
    BOOL _rendered;
    BOOL _scheduled;
    OTTemplateContext *_template;
    CGSize _laidOut;
    CGFloat _keyboard;
}

- (instancetype)initWithController:(UIViewController *)controller container:(UIView *)container templatePath:(NSString *)templatePath dataPath:(NSString *)dataPath onReady:(void (^)(UIView *))onReady {
    self = [super init];
    if (self) {
        _controller = controller;
        _container = container;
        _templatePath = [templatePath copy];
        _dataPath = [dataPath copy];
        _onReady = [onReady copy];
        [OTIme installOn:controller.view];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboard:) name:UIKeyboardWillChangeFrameNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)noteSafeArea {
    _insetsApplied = YES;
    [self schedule];
}

- (void)noteLayout {
    [self schedule];
}

- (void)noteAppear {
    if (!_insetsApplied) {
        _insetsApplied = YES;
        [self schedule];
    }
}

- (void)schedule {
    if (_scheduled) {
        return;
    }
    _scheduled = YES;
    __weak TemplateScreen *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        TemplateScreen *self = weakSelf;
        if (!self) {
            return;
        }
        self->_scheduled = NO;
        [self render];
    });
}

- (void)keyboard:(NSNotification *)note {
    UIView *root = _controller.view;
    NSValue *value = note.userInfo[UIKeyboardFrameEndUserInfoKey];
    if (!root || ![value isKindOfClass:[NSValue class]]) {
        return;
    }
    CGRect frame = [root convertRect:value.CGRectValue fromView:nil];
    CGRect overlap = CGRectIntersection(root.bounds, frame);
    CGFloat height = CGRectIsNull(overlap) ? 0 : overlap.size.height;
    _keyboard = frame.origin.y >= CGRectGetMaxY(root.bounds) - 1 ? 0 : height;
    [self schedule];
}

- (DemoTopBar *)topBar {
    for (UIView *child in _controller.view.subviews) {
        if ([child isKindOfClass:[DemoTopBar class]]) {
            return (DemoTopBar *)child;
        }
    }
    return nil;
}

- (void)applyInsets {
    UIView *root = _controller.view;
    if (!root) {
        return;
    }
    UIEdgeInsets safe = root.safeAreaInsets;
    CGFloat bottom = MAX(safe.bottom, _keyboard);
    DemoTopBar *bar = [self topBar];
    CGFloat barHeight = bar ? [DemoTopBar barHeight] : 0;
    if (bar) {
        bar.frame = CGRectMake(safe.left, safe.top, MAX(root.bounds.size.width - safe.left - safe.right, 0), barHeight);
        [root bringSubviewToFront:bar];
    }
    CGFloat top = safe.top + barHeight;
    _container.frame = CGRectMake(safe.left, top, MAX(root.bounds.size.width - safe.left - safe.right, 0), MAX(root.bounds.size.height - top - bottom, 0));
}

- (void)render {
    [self applyInsets];
    if (!_insetsApplied || _container.bounds.size.width <= 0 || _container.bounds.size.height <= 0) {
        return;
    }
    if (_rendered) {
        if (CGSizeEqualToSize(_container.bounds.size, _laidOut)) {
            return;
        }
        _laidOut = _container.bounds.size;
        if (_template) {
            [OTEngine.shared relayoutTemplate:_template viewport:_container.bounds.size];
            _template.rootView.frame = _container.bounds;
        }
        return;
    }
    _rendered = YES;
    _laidOut = _container.bounds.size;
    OTTemplateContext *template = [OTEngine.shared buildTemplateWithBizId:@"demo" templateId:@"screen" templatePath:_templatePath];
    _template = template;
    if (_dataPath.length > 0) {
        NSError *error = nil;
        NSString *json = [OTAssets text:_dataPath error:&error];
        if (!json || ![OTEngine.shared setData:json forTemplate:template error:&error]) {
            if (error.localizedDescription.length > 0) {
                [OTToast show:error.localizedDescription inView:_container];
            }
            return;
        }
    }
    NSError *error = nil;
    UIView *view = [OTEngine.shared createViewForTemplate:template viewport:_container.bounds.size error:&error];
    if (!view) {
        if (error.localizedDescription.length > 0) {
            [OTToast show:error.localizedDescription inView:_container];
        }
        return;
    }
    view.frame = _container.bounds;
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_container addSubview:view];
    if (_onReady) {
        _onReady(view);
    }
}

@end
