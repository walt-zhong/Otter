#import "OTEngine.h"
#import "OTBridge.h"
#import "../Render/OTNodes.h"
#import "../Render/OTViewTree.h"

@implementation OTTemplateContext

- (instancetype)initWithBizId:(NSString *)bizId templateId:(NSString *)templateId templatePath:(NSString *)templatePath {
    self = [super init];
    if (self) {
        _bizId = [bizId copy];
        _templateId = [templateId copy];
        _templatePath = [templatePath copy];
        _events = @{};
        _viewIds = [NSMutableDictionary dictionary];
        _scale = 1;
    }
    return self;
}

- (void)releaseTree:(UIView *)view {
    if (!view) {
        return;
    }
    if ([view isKindOfClass:[OTImageView class]]) {
        [(OTImageView *)view releaseImage];
    }
    if ([view isKindOfClass:[OTLottieView class]]) {
        [(OTLottieView *)view releaseAnimation];
    }
    for (UIView *child in view.subviews) {
        [self releaseTree:child];
    }
}

- (void)releaseTemplate {
    if ([self.rootView isKindOfClass:[OTLottieView class]]) {
        [(OTLottieView *)self.rootView releaseAnimation];
    }
    [self releaseTree:self.rootView];
    [self.rootView removeFromSuperview];
    self.rootView = nil;
    self.parsed = nil;
    self.laidOut = nil;
    self.data = nil;
    self.events = @{};
    [self.viewIds removeAllObjects];
}

@end

@implementation OTEngine

+ (OTEngine *)shared {
    static OTEngine *engine;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ engine = [OTEngine new]; });
    return engine;
}

- (OTTemplateContext *)buildTemplateWithBizId:(NSString *)bizId templateId:(NSString *)templateId templatePath:(NSString *)templatePath {
    return [[OTTemplateContext alloc] initWithBizId:bizId templateId:templateId templatePath:templatePath];
}

- (BOOL)setData:(NSString *)json forTemplate:(OTTemplateContext *)template error:(NSError **)error {
    JSONObject *data = [OTData parseObject:json error:error];
    if (!data) {
        return NO;
    }
    template.data = data;
    return YES;
}

- (UIView *)createViewForTemplate:(OTTemplateContext *)template viewport:(CGSize)viewport error:(NSError **)error {
    NSString *json = [OTAssets text:template.templatePath error:error];
    if (!json) {
        return nil;
    }
    ParsedTemplate *parsed = [TemplateJsonParser parseJSON:json error:error];
    if (!parsed) {
        return nil;
    }
    template.parsed = parsed;
    template.events = parsed.events ?: @{};
    template.viewport = viewport;
    template.scale = [ScreenAdapt scaleForWindowWidth:viewport.width];
    template.viewIds = [NSMutableDictionary dictionary];
    OTLaidOutNode *laid = [OTLayoutCall layoutRoot:parsed.root data:template.data viewport:viewport windowWidth:viewport.width error:error];
    if (!laid) {
        return nil;
    }
    template.laidOut = laid;
    UIView *view = [OTViewTree buildParsed:parsed.root laid:laid template:template itemData:nil error:error];
    if (!view) {
        return nil;
    }
    view.frame = CGRectMake(0, 0, viewport.width, viewport.height);
    template.rootView = view;
    return view;
}

- (void)relayoutTemplate:(OTTemplateContext *)template viewport:(CGSize)viewport {
    if (!template.parsed || !template.rootView) {
        return;
    }
    template.viewport = viewport;
    template.scale = [ScreenAdapt scaleForWindowWidth:viewport.width];
    OTLaidOutNode *laid = [OTLayoutCall layoutRoot:template.parsed.root data:template.data viewport:viewport windowWidth:viewport.width error:nil];
    if (!laid) {
        return;
    }
    template.laidOut = laid;
    template.rootView.frame = CGRectMake(0, 0, viewport.width, viewport.height);
    [OTViewTree applyFrames:template.rootView laid:laid];
    template.rootView.frame = CGRectMake(0, 0, viewport.width, viewport.height);
}

- (BOOL)rebindTemplate:(OTTemplateContext *)template error:(NSError **)error {
    if (!template.parsed || !template.rootView) {
        return YES;
    }
    NSDictionary *saved = [template.viewIds copy];
    CGSize viewport = template.viewport;
    OTLaidOutNode *laid = [OTLayoutCall layoutRoot:template.parsed.root data:template.data viewport:viewport windowWidth:viewport.width error:error];
    if (!laid) {
        template.viewIds = [saved mutableCopy] ?: [NSMutableDictionary dictionary];
        return NO;
    }
    template.viewIds = [NSMutableDictionary dictionary];
    template.laidOut = laid;
    if (![OTViewTree rebindView:template.rootView parsed:template.parsed.root laid:laid template:template error:error]) {
        template.viewIds = [saved mutableCopy] ?: [NSMutableDictionary dictionary];
        return NO;
    }
    [OTViewTree applyFrames:template.rootView laid:laid];
    return YES;
}

- (void)releaseTemplate:(OTTemplateContext *)template {
    [template releaseTemplate];
}

@end
