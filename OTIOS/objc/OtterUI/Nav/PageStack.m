#import "PageStack.h"
#import "../Engine/OTEngine.h"
#import "../Engine/OTBridge.h"
#import "../Render/OTNodes.h"

static const NSInteger OTPageMaxStateCharacters = 200000;

@interface OTPageFrame : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *templatePath;
@property (nonatomic, strong, nullable) JSONObject *data;
@property (nonatomic, strong, nullable) OTTemplateContext *template;
@property (nonatomic, copy, nullable) NSString *slotKey;
@property (nonatomic, assign) NSInteger slotIndex;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *scrolls;
@end

@implementation OTPageFrame
- (instancetype)init {
    self = [super init];
    if (self) {
        _slotIndex = -1;
        _scrolls = [NSMutableDictionary dictionary];
    }
    return self;
}
@end

@interface OTPageSaved : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy, nullable) NSString *data;
@property (nonatomic, copy, nullable) NSString *slotKey;
@property (nonatomic, assign) NSInteger slotIndex;
@property (nonatomic, copy) NSDictionary<NSString *, NSDictionary *> *scrolls;
@end

@implementation OTPageSaved
@end

@interface OTPageForm : NSObject
+ (void)snapshot:(nullable UIView *)root data:(nullable JSONObject *)data;
+ (void)restore:(nullable UIView *)root data:(nullable JSONObject *)data;
+ (void)captureScroll:(nullable UIView *)root into:(NSMutableDictionary<NSString *, NSDictionary *> *)into;
+ (void)restoreScroll:(nullable UIView *)root scrolls:(NSDictionary<NSString *, NSDictionary *> *)scrolls;
@end

@implementation PageStack {
    UIViewController *_host;
    UIView *_insetRoot;
    UIView *_container;
    PageRouteTable *_routes;
    NSString *_routePath;
    NSString *_bizId;
    NSString *_templateId;
    NSMutableArray<OTPageFrame *> *_frames;
    NSMutableArray<NSString *> *_names;
    UIView *_stage;
    BOOL _ownsInsets;
    BOOL _insetsApplied;
    BOOL _startAttempted;
    BOOL _released;
    CGSize _laidOutSize;
    CGFloat _keyboard;
    OTPageFrame *_pendingDrop;
    OTPageFrame *_dismissing;
    NSInteger _generation;
    NSArray<OTPageSaved *> *_restored;
    UIView *_touchGuard;
    UIScreenEdgePanGestureRecognizer *_edge;
    BOOL _scheduled;
}

+ (NSInteger)maxStateCharacters {
    return OTPageMaxStateCharacters;
}

+ (NSMapTable<UIViewController *, NSMutableArray<PageStack *> *> *)groups {
    static NSMapTable *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ table = [NSMapTable weakToStrongObjectsMapTable]; });
    return table;
}

+ (NSMapTable<UIViewController *, PageStack *> *)active {
    static NSMapTable *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ table = [NSMapTable weakToStrongObjectsMapTable]; });
    return table;
}

+ (PageStack *)attachWithHost:(UIViewController *)host insetRoot:(UIView *)insetRoot container:(UIView *)container routePath:(NSString *)routePath bizId:(NSString *)bizId templateId:(NSString *)templateId error:(NSError **)error {
    NSString *json = [OTAssets text:routePath error:error];
    if (!json) {
        return nil;
    }
    PageRouteTable *routes = [PageRouteParser parseJSON:json error:error];
    if (!routes) {
        return nil;
    }
    NSMutableArray<PageStack *> *list = [[self groups] objectForKey:host] ?: [NSMutableArray array];
    PageStack *stack = [[PageStack alloc] initWithHost:host insetRoot:insetRoot container:container routes:routes routePath:routePath bizId:bizId templateId:templateId];
    BOOL owned = NO;
    for (PageStack *existing in list) {
        if (existing->_ownsInsets) {
            owned = YES;
            break;
        }
    }
    stack->_ownsInsets = !owned;
    [list addObject:stack];
    [[self groups] setObject:list forKey:host];
    if (![[self active] objectForKey:host]) {
        [[self active] setObject:stack forKey:host];
    }
    [stack install];
    return stack;
}

+ (PageStack *)find:(UIView *)view {
    UIViewController *controller = view.ot_controller;
    if (!controller) {
        return nil;
    }
    return [[self active] objectForKey:controller];
}

- (instancetype)initWithHost:(UIViewController *)host insetRoot:(UIView *)insetRoot container:(UIView *)container routes:(PageRouteTable *)routes routePath:(NSString *)routePath bizId:(NSString *)bizId templateId:(NSString *)templateId {
    self = [super init];
    if (self) {
        _host = host;
        _insetRoot = insetRoot;
        _container = container;
        _routes = routes;
        _routePath = [routePath copy];
        _bizId = [bizId copy];
        _templateId = [templateId copy];
        _frames = [NSMutableArray array];
        _names = [NSMutableArray array];
        _stage = [UIView new];
        _touchGuard = [UIView new];
    }
    return self;
}

- (NSInteger)depth {
    return _names.count;
}

- (void)activate {
    if (_released) {
        return;
    }
    [[PageStack active] setObject:self forKey:_host];
    for (PageStack *stack in [[PageStack groups] objectForKey:_host]) {
        [stack syncBack];
    }
}

- (void)releaseStack {
    if (_released) {
        return;
    }
    _released = YES;
    [self endMotionKeep:nil];
    for (OTPageFrame *frame in _frames) {
        [self sever:frame];
    }
    [_frames removeAllObjects];
    [_names removeAllObjects];
    if (_stage.superview == _container) {
        [_stage removeFromSuperview];
    }
    NSMutableArray *list = [[PageStack groups] objectForKey:_host];
    [list removeObject:self];
    if (list.count == 0) {
        [[PageStack groups] removeObjectForKey:_host];
    }
    if ([[PageStack active] objectForKey:_host] == self) {
        [[PageStack active] removeObjectForKey:_host];
    }
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)layoutContainers {
    PageStack *owner = self;
    for (PageStack *stack in [[PageStack groups] objectForKey:_host]) {
        if (stack->_ownsInsets) {
            owner = stack;
            break;
        }
    }
    UIEdgeInsets safe = owner->_insetRoot.safeAreaInsets;
    CGFloat bottom = MAX(safe.bottom, owner->_keyboard);
    CGRect rootInset = UIEdgeInsetsInsetRect(owner->_insetRoot.bounds, UIEdgeInsetsMake(safe.top, safe.left, bottom, safe.right));
    CGRect local = [_container convertRect:rootInset fromView:owner->_insetRoot];
    CGRect fitted = CGRectIntersection(_container.bounds, local);
    _stage.frame = CGRectIsEmpty(fitted) ? _container.bounds : fitted;
    _insetsApplied = YES;
    [self render];
}

- (void)open:(NSString *)page raw:(JSONObject *)raw item:(JSONObject *)item pageData:(JSONObject *)pageData {
    if (_released) {
        return;
    }
    [self openNow:page raw:raw item:item pageData:pageData];
}

- (void)replace:(NSString *)page raw:(JSONObject *)raw item:(JSONObject *)item pageData:(JSONObject *)pageData {
    if (_released) {
        return;
    }
    [self replaceNow:page raw:raw item:item pageData:pageData];
}

- (BOOL)pop:(JSONObject *)raw {
    if (_released || _names.count <= 1) {
        return NO;
    }
    return [self popNow:raw];
}

- (BOOL)popTo:(NSString *)page raw:(JSONObject *)raw {
    if (_released || ![_names containsObject:page]) {
        return NO;
    }
    return [self popToNow:page raw:raw];
}

- (void)editCurrentData:(void (^)(JSONObject *))block {
    if (_released || _frames.count == 0 || !block) {
        return;
    }
    OTPageFrame *frame = _frames.lastObject;
    if (!frame.data) {
        frame.data = frame.template.data ?: [JSONObject new];
        if (!frame.template.data) {
            frame.template.data = frame.data;
        }
    }
    [OTPageForm snapshot:frame.template.rootView data:frame.data];
    block(frame.data);
}

- (void)rebindCurrent {
    if (_released) {
        return;
    }
    OTTemplateContext *context = _frames.lastObject.template;
    if (!context.rootView) {
        return;
    }
    [OTEngine.shared rebindTemplate:context error:nil];
    [OTPageForm restore:context.rootView data:_frames.lastObject.data];
}

- (NSString *)exportState {
    if (_released || _frames.count == 0) {
        return nil;
    }
    NSMutableArray *pages = [NSMutableArray array];
    for (OTPageFrame *frame in _frames) {
        [OTPageForm snapshot:frame.template.rootView data:frame.data];
        [OTPageForm captureScroll:frame.template.rootView into:frame.scrolls];
        NSMutableDictionary *page = [@{@"name": frame.name} mutableCopy];
        NSString *data = [OTData text:frame.data];
        if (data) {
            page[@"data"] = data;
        }
        if (frame.slotKey) {
            page[@"slotKey"] = frame.slotKey;
            page[@"slotIndex"] = @(frame.slotIndex);
        }
        if (frame.scrolls.count > 0) {
            NSMutableDictionary *scrolls = [NSMutableDictionary dictionary];
            for (NSString *key in frame.scrolls) {
                scrolls[key] = frame.scrolls[key];
            }
            page[@"scrolls"] = scrolls;
        }
        [pages addObject:page];
    }
    NSDictionary *root = @{@"route": _routePath, @"bizId": _bizId, @"templateId": _templateId, @"pages": pages};
    NSData *data = [NSJSONSerialization dataWithJSONObject:root options:0 error:nil];
    NSString *text = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
    if (text.length > OTPageMaxStateCharacters) {
        return nil;
    }
    return text;
}

- (void)restoreState:(NSString *)text {
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *root = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if (![root isKindOfClass:[NSDictionary class]]) {
        return;
    }
    if (![root[@"route"] isEqualToString:_routePath] || ![root[@"bizId"] isEqualToString:_bizId] || ![root[@"templateId"] isEqualToString:_templateId]) {
        return;
    }
    NSArray *pages = root[@"pages"];
    if (![pages isKindOfClass:[NSArray class]] || pages.count == 0) {
        return;
    }
    NSMutableArray<OTPageSaved *> *parsed = [NSMutableArray array];
    for (NSDictionary *page in pages) {
        if (![page isKindOfClass:[NSDictionary class]]) {
            return;
        }
        NSString *name = page[@"name"];
        if (![name isKindOfClass:[NSString class]] || !_routes.pages[name]) {
            return;
        }
        NSMutableDictionary *scrolls = [NSMutableDictionary dictionary];
        NSDictionary *rawScrolls = page[@"scrolls"];
        if ([rawScrolls isKindOfClass:[NSDictionary class]]) {
            for (NSString *key in rawScrolls) {
                NSDictionary *one = rawScrolls[key];
                if (![one isKindOfClass:[NSDictionary class]]) {
                    continue;
                }
                scrolls[key] = @{
                    @"position": @([one[@"position"] integerValue]),
                    @"offset": @([one[@"offset"] doubleValue])
                };
            }
        }
        OTPageSaved *saved = [OTPageSaved new];
        saved.name = name;
        saved.data = [page[@"data"] isKindOfClass:[NSString class]] ? page[@"data"] : nil;
        saved.slotKey = [page[@"slotKey"] isKindOfClass:[NSString class]] ? page[@"slotKey"] : nil;
        saved.slotIndex = [page[@"slotIndex"] integerValue];
        saved.scrolls = scrolls;
        [parsed addObject:saved];
    }
    _restored = parsed;
}

- (void)install {
    _stage.clipsToBounds = YES;
    [_container addSubview:_stage];
    _stage.frame = _container.bounds;
    _stage.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _touchGuard.backgroundColor = UIColor.clearColor;
    _touchGuard.userInteractionEnabled = YES;
    UIScreenEdgePanGestureRecognizer *edge = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(edgePan:)];
    edge.edges = _container.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft ? UIRectEdgeRight : UIRectEdgeLeft;
    edge.delegate = self;
    [_container addGestureRecognizer:edge];
    _edge = edge;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboard:) name:UIKeyboardWillChangeFrameNotification object:nil];
    if (!_ownsInsets) {
        for (PageStack *stack in [[PageStack groups] objectForKey:_host]) {
            if (stack->_insetsApplied) {
                _insetsApplied = YES;
                break;
            }
        }
    } else {
        _insetsApplied = YES;
    }
    [self layoutContainers];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return _names.count > 1 && !_released;
}

- (void)edgePan:(UIScreenEdgePanGestureRecognizer *)gesture {
    if (_names.count <= 1) {
        return;
    }
    OTPageFrame *top = _frames.lastObject;
    UIView *view = top.template.rootView;
    if (!view) {
        return;
    }
    CGFloat width = MAX(_stage.bounds.size.width, 1);
    CGFloat translation = [gesture translationInView:_stage].x;
    BOOL rtl = _stage.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
    CGFloat travel = rtl ? MIN(translation, 0) : MAX(translation, 0);
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [view.layer removeAllAnimations];
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        view.transform = CGAffineTransformMakeTranslation(travel, 0);
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        CGFloat velocity = [gesture velocityInView:_stage].x;
        BOOL passed = fabs(travel) > width * 0.35 || fabs(velocity) > 800;
        if (passed && gesture.state == UIGestureRecognizerStateEnded) {
            [self pop:nil];
        } else {
            [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                view.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
    }
}

- (void)keyboard:(NSNotification *)note {
    if (!_ownsInsets) {
        return;
    }
    NSValue *value = note.userInfo[UIKeyboardFrameEndUserInfoKey];
    if (![value isKindOfClass:[NSValue class]]) {
        return;
    }
    CGRect frame = [value CGRectValue];
    CGRect local = [_insetRoot convertRect:frame fromView:nil];
    CGRect overlapRect = CGRectIntersection(_insetRoot.bounds, local);
    CGFloat overlap = CGRectIsNull(overlapRect) ? 0 : overlapRect.size.height;
    _keyboard = local.origin.y >= CGRectGetMaxY(_insetRoot.bounds) - 1 ? 0 : overlap;
    [self layoutContainers];
    if (self.onInsets) {
        self.onInsets();
    }
}

- (void)render {
    if (_released || !_insetsApplied || _container.bounds.size.width <= 0 || _container.bounds.size.height <= 0) {
        return;
    }
    if (CGRectIsEmpty(_stage.frame)) {
        _stage.frame = _container.bounds;
    }
    if (_frames.count > 0) {
        if (CGSizeEqualToSize(_container.bounds.size, _laidOutSize)) {
            return;
        }
        _laidOutSize = _container.bounds.size;
        [self relayout:_frames.lastObject];
        return;
    }
    if (_startAttempted) {
        return;
    }
    _startAttempted = YES;
    [self openStart];
}

- (void)openStart {
    NSArray<OTPageSaved *> *saved = _restored;
    _restored = nil;
    if (saved.count == 0) {
        [self openNow:_routes.start raw:nil item:nil pageData:nil];
        return;
    }
    [saved enumerateObjectsUsingBlock:^(OTPageSaved *page, NSUInteger index, BOOL *stop) {
        PageRoute *route = self->_routes.pages[page.name];
        if (!route) {
            [self abandon];
            [self openNow:self->_routes.start raw:nil item:nil pageData:nil];
            *stop = YES;
            return;
        }
        JSONObject *data = nil;
        if (page.data.length > 0) {
            data = [OTData parseObject:page.data error:nil];
            if (!data) {
                [self abandon];
                [self openNow:self->_routes.start raw:nil item:nil pageData:nil];
                *stop = YES;
                return;
            }
        }
        OTPageFrame *frame = [OTPageFrame new];
        frame.name = page.name;
        frame.templatePath = route.template;
        frame.data = data;
        frame.slotKey = page.slotKey;
        frame.slotIndex = page.slotIndex;
        frame.scrolls = [page.scrolls mutableCopy] ?: [NSMutableDictionary dictionary];
        [self->_frames addObject:frame];
        [self->_names addObject:frame.name];
        if (index == saved.count - 1 && ![self materialize:frame under:NO]) {
            [self abandon];
            [self openNow:self->_routes.start raw:nil item:nil pageData:nil];
            *stop = YES;
        }
    }];
    [self syncBack];
    _laidOutSize = _container.bounds.size;
}

- (void)abandon {
    for (OTPageFrame *frame in _frames) {
        [self sever:frame];
    }
    [_frames removeAllObjects];
    [_names removeAllObjects];
}

- (void)openNow:(NSString *)page raw:(JSONObject *)raw item:(JSONObject *)item pageData:(JSONObject *)pageData {
    [OTIme dismiss:_insetRoot];
    PageRoute *route = nil;
    OTPageFrame *current = nil;
    JSONObject *overlay = nil;
    if (![self resolve:page raw:raw item:item pageData:pageData replace:NO route:&route current:&current overlay:&overlay]) {
        return;
    }
    OTPageFrame *frame = nil;
    UIView *view = nil;
    if (![self createShown:page route:route current:current overlay:overlay item:item frame:&frame view:&view]) {
        return;
    }
    [self showFrame:frame view:view];
}

- (void)replaceNow:(NSString *)page raw:(JSONObject *)raw item:(JSONObject *)item pageData:(JSONObject *)pageData {
    [OTIme dismiss:_insetRoot];
    PageRoute *route = nil;
    OTPageFrame *current = nil;
    JSONObject *overlay = nil;
    if (![self resolve:page raw:raw item:item pageData:pageData replace:YES route:&route current:&current overlay:&overlay]) {
        return;
    }
    OTPageFrame *frame = nil;
    UIView *view = nil;
    if (![self createShown:page route:route current:current overlay:overlay item:item frame:&frame view:&view]) {
        return;
    }
    OTPageFrame *removed = _frames.count == 0 ? nil : _frames.lastObject;
    if (removed) {
        [_frames removeLastObject];
        [_names removeLastObject];
    }
    if (removed && _frames.count > 0) {
        _pendingDrop = removed;
        [_frames addObject:frame];
        [_names addObject:frame.name];
        [self syncBack];
        [self slideIn:view];
    } else if (removed) {
        [self swap:frame view:view removed:removed];
    } else {
        [self showFrame:frame view:view];
    }
    _laidOutSize = _container.bounds.size;
}

- (BOOL)resolve:(NSString *)page raw:(JSONObject *)raw item:(JSONObject *)item pageData:(JSONObject *)pageData replace:(BOOL)replace route:(PageRoute **)routeOut current:(OTPageFrame **)currentOut overlay:(JSONObject **)overlayOut {
    PageRoute *route = _routes.pages[page];
    if (_released || !route) {
        [OTToast show:@"这个页面还打不开" inView:_container];
        return NO;
    }
    OTPageFrame *current = _frames.lastObject;
    if (current && pageData && current.data != pageData && current.template.data != pageData) {
        return NO;
    }
    if (current) {
        [OTPageForm snapshot:current.template.rootView data:current.data];
        [OTPageForm captureScroll:current.template.rootView into:current.scrolls];
    }
    JSONObject *scope = [PageParams merge:pageData ?: current.data overlay:item];
    JSONObject *overlay = raw ? [OTData evaluate:raw scope:scope] : nil;
    if (!replace && current && [current.name isEqualToString:page] && [PageParams matches:current.data overlay:overlay]) {
        return NO;
    }
    if (routeOut) *routeOut = route;
    if (currentOut) *currentOut = current;
    if (overlayOut) *overlayOut = overlay;
    return YES;
}

- (BOOL)createShown:(NSString *)page route:(PageRoute *)route current:(OTPageFrame *)current overlay:(JSONObject *)overlay item:(JSONObject *)item frame:(OTPageFrame **)frameOut view:(UIView **)viewOut {
    OTTemplateContext *context = nil;
    JSONObject *base = nil;
    if (route.data.length > 0) {
        NSError *error = nil;
        NSString *text = [OTAssets text:route.data error:&error];
        base = text ? [OTData parseObject:text error:&error] : nil;
        if (!base) {
            [OTToast show:@"这个页面还打不开" inView:_container];
            return NO;
        }
    }
    context = [OTEngine.shared buildTemplateWithBizId:_bizId templateId:_templateId templatePath:route.template];
    JSONObject *merged = [PageParams merge:base overlay:overlay];
    NSString *mergedText = [OTData text:merged];
    NSError *error = nil;
    if (mergedText && ![OTEngine.shared setData:mergedText forTemplate:context error:&error]) {
        [context releaseTemplate];
        [OTToast show:@"这个页面还打不开" inView:_container];
        return NO;
    }
    UIView *view = [OTEngine.shared createViewForTemplate:context viewport:_container.bounds.size error:&error];
    if (!view) {
        [context releaseTemplate];
        [OTToast show:@"这个页面还打不开" inView:_container];
        return NO;
    }
    NSString *slotKey = nil;
    NSInteger slotIndex = -1;
    [PageParams findItemInPage:current.data item:item key:&slotKey index:&slotIndex];
    OTPageFrame *frame = [OTPageFrame new];
    frame.name = page;
    frame.templatePath = route.template;
    frame.data = context.data;
    frame.template = context;
    frame.slotKey = slotKey;
    frame.slotIndex = slotKey ? slotIndex : -1;
    if (frameOut) *frameOut = frame;
    if (viewOut) *viewOut = view;
    return YES;
}

- (void)showFrame:(OTPageFrame *)frame view:(UIView *)view {
    [self endMotionKeep:nil];
    if (_frames.lastObject) {
        OTPageFrame *covered = _frames.lastObject;
        [OTPageForm snapshot:covered.template.rootView data:covered.data];
        [OTPageForm captureScroll:covered.template.rootView into:covered.scrolls];
        _pendingDrop = covered;
    }
    [_frames addObject:frame];
    [_names addObject:frame.name];
    [self syncBack];
    [self slideIn:view];
    _laidOutSize = _container.bounds.size;
}

- (void)swap:(OTPageFrame *)frame view:(UIView *)view removed:(OTPageFrame *)removed {
    [self endMotionKeep:nil];
    [_frames addObject:frame];
    [_names addObject:frame.name];
    [self syncBack];
    [self place:view under:NO];
    [self sever:removed];
}

- (BOOL)popNow:(JSONObject *)raw {
    if (_released || _names.count <= 1) {
        return NO;
    }
    [OTIme dismiss:_insetRoot];
    [_names removeLastObject];
    OTPageFrame *frame = _frames.lastObject;
    [_frames removeLastObject];
    OTPageFrame *revealed = _frames.lastObject;
    if (!revealed) {
        return NO;
    }
    [self endMotionKeep:revealed];
    [OTPageForm snapshot:frame.template.rootView data:frame.data];
    JSONObject *result = [self evaluateBack:raw ?: [self declaredBack:frame] scope:frame.data];
    if (result.size > 0) {
        [self applyResult:revealed leaving:frame result:result];
    }
    BOOL keepLive = result.size == 0 && revealed.template.rootView != nil;
    if (!keepLive) {
        [self sever:revealed];
        if (![self materialize:revealed under:frame.template.rootView != nil]) {
            [OTToast show:@"这个页面还打不开" inView:_container];
        }
    }
    [self syncBack];
    [self dismiss:frame];
    _laidOutSize = _container.bounds.size;
    return YES;
}

- (BOOL)popToNow:(NSString *)page raw:(JSONObject *)raw {
    NSUInteger index = [_names indexOfObject:page];
    if (index == NSNotFound) {
        return NO;
    }
    [OTIme dismiss:_insetRoot];
    if (index == _names.count - 1) {
        [self mergeIntoTop:raw];
        return YES;
    }
    NSArray<OTPageFrame *> *removed = [_frames subarrayWithRange:NSMakeRange(index + 1, _frames.count - index - 1)];
    [_frames removeObjectsInRange:NSMakeRange(index + 1, _frames.count - index - 1)];
    [_names removeObjectsInRange:NSMakeRange(index + 1, _names.count - index - 1)];
    OTPageFrame *revealed = _frames.lastObject;
    OTPageFrame *visible = removed.firstObject;
    if (!revealed || !visible) {
        return NO;
    }
    OTPageFrame *covering = removed.lastObject ?: visible;
    [self endMotionKeep:revealed];
    [OTPageForm snapshot:visible.template.rootView data:visible.data];
    JSONObject *result = [self evaluateBack:raw scope:visible.data];
    if (result.size > 0) {
        [self applyResult:revealed leaving:covering result:result];
    }
    BOOL keepLive = result.size == 0 && revealed.template.rootView != nil;
    if (!keepLive) {
        [self sever:revealed];
        if (![self materialize:revealed under:visible.template.rootView != nil]) {
            [OTToast show:@"这个页面还打不开" inView:_container];
        }
    }
    [self syncBack];
    for (NSUInteger extra = 1; extra < removed.count; extra++) {
        [self sever:removed[extra]];
    }
    [self dismiss:visible];
    _laidOutSize = _container.bounds.size;
    return YES;
}

- (void)mergeIntoTop:(JSONObject *)raw {
    OTPageFrame *top = _frames.lastObject;
    if (!top) {
        return;
    }
    [self endMotionKeep:top];
    [OTPageForm snapshot:top.template.rootView data:top.data];
    JSONObject *result = [self evaluateBack:raw scope:top.data];
    if (result.size > 0) {
        top.data = [PageParams merge:top.data overlay:result];
        [self sever:top];
        if (![self materialize:top under:NO]) {
            [OTToast show:@"这个页面还打不开" inView:_container];
        }
    }
}

- (void)applyResult:(OTPageFrame *)revealed leaving:(OTPageFrame *)leaving result:(JSONObject *)result {
    JSONArray *array = leaving.slotKey ? [revealed.data getJSONArray:leaving.slotKey] : nil;
    JSONObject *item = (array && leaving.slotIndex >= 0 && leaving.slotIndex < array.size) ? [array getJSONObject:leaving.slotIndex] : nil;
    if (item) {
        [PageParams mergeInto:item overlay:result];
        return;
    }
    revealed.data = [PageParams merge:revealed.data overlay:result];
}

- (JSONObject *)evaluateBack:(JSONObject *)raw scope:(JSONObject *)scope {
    if (!raw) {
        return nil;
    }
    return [OTData evaluate:raw scope:scope];
}

- (JSONObject *)declaredBack:(OTPageFrame *)frame {
    NSMutableArray<JSONObject *> *found = [NSMutableArray array];
    for (JSONObject *event in frame.template.events.allValues) {
        if (![[event getString:@"class"] isEqualToString:@"nav"]) {
            continue;
        }
        JSONObject *params = [event getJSONObject:@"params"];
        if (![[params getString:@"fun"] isEqualToString:@"back"]) {
            continue;
        }
        JSONObject *payload = [params getJSONObject:@"params"];
        if (payload) {
            [found addObject:payload];
        }
    }
    return found.count == 1 ? found[0] : nil;
}

- (BOOL)materialize:(OTPageFrame *)frame under:(BOOL)under {
    UIView *existing = frame.template.rootView;
    if (existing) {
        if (!existing.superview) {
            [self place:existing under:under];
        }
        [OTPageForm restore:existing data:frame.data];
        [OTPageForm restoreScroll:existing scrolls:frame.scrolls];
        [self relayout:frame];
        return YES;
    }
    OTTemplateContext *context = [OTEngine.shared buildTemplateWithBizId:_bizId templateId:_templateId templatePath:frame.templatePath];
    NSError *error = nil;
    NSString *text = [OTData text:frame.data];
    if (text && ![OTEngine.shared setData:text forTemplate:context error:&error]) {
        [context releaseTemplate];
        frame.template = nil;
        return NO;
    }
    UIView *view = [OTEngine.shared createViewForTemplate:context viewport:_container.bounds.size error:&error];
    if (!view) {
        [context releaseTemplate];
        frame.template = nil;
        return NO;
    }
    frame.template = context;
    frame.data = context.data;
    [OTPageForm restore:view data:frame.data];
    [self place:view under:under];
    [OTPageForm restoreScroll:view scrolls:frame.scrolls];
    [self relayout:frame];
    return YES;
}

- (void)place:(UIView *)view under:(BOOL)under {
    if (view.superview == _stage) {
        return;
    }
    view.frame = _stage.bounds;
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if (under && _stage.subviews.count > 0) {
        [_stage insertSubview:view atIndex:0];
    } else {
        [_stage addSubview:view];
    }
}

- (void)slideIn:(UIView *)view {
    [self holdTouches];
    [self place:view under:NO];
    CGFloat travel = [self travel];
    if (travel == 0) {
        [self severPending];
        [self releaseTouches];
        return;
    }
    view.transform = CGAffineTransformMakeTranslation(travel, 0);
    NSInteger token = [self nextGeneration];
    __weak PageStack *weakSelf = self;
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        view.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        PageStack *self = weakSelf;
        if (!self || token != self->_generation || self->_released) {
            return;
        }
        [self severPending];
        if (!self->_dismissing) {
            [self releaseTouches];
        }
    }];
}

- (void)dismiss:(OTPageFrame *)frame {
    UIView *view = frame.template.rootView;
    if (!view) {
        [self sever:frame];
        [self releaseTouches];
        return;
    }
    CGFloat travel = [self travel];
    if (travel == 0) {
        [self sever:frame];
        [self releaseTouches];
        return;
    }
    [self holdTouches];
    [_stage bringSubviewToFront:view];
    _dismissing = frame;
    NSInteger token = [self nextGeneration];
    __weak PageStack *weakSelf = self;
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        view.transform = CGAffineTransformMakeTranslation(travel, 0);
    } completion:^(BOOL finished) {
        PageStack *self = weakSelf;
        if (!self || token != self->_generation || self->_released) {
            return;
        }
        if (self->_dismissing == frame) {
            self->_dismissing = nil;
            [self sever:frame];
        }
        if (!self->_dismissing) {
            [self releaseTouches];
        }
    }];
}

- (CGFloat)travel {
    CGFloat width = _stage.bounds.size.width > 0 ? _stage.bounds.size.width : _container.bounds.size.width;
    if (width <= 0 || _container.bounds.size.height <= 0 || UIAccessibilityIsReduceMotionEnabled()) {
        return 0;
    }
    return _stage.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft ? -width : width;
}

- (void)holdTouches {
    _touchGuard.frame = _stage.bounds;
    _touchGuard.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_stage addSubview:_touchGuard];
}

- (void)releaseTouches {
    [_touchGuard removeFromSuperview];
}

- (void)endMotionKeep:(OTPageFrame *)keep {
    _generation += 1;
    for (UIView *view in _stage.subviews) {
        [view.layer removeAllAnimations];
        view.transform = CGAffineTransformIdentity;
    }
    [self releaseTouches];
    if (_pendingDrop && _pendingDrop != keep) {
        [self sever:_pendingDrop];
    }
    _pendingDrop = nil;
    if (_dismissing && _dismissing != keep) {
        [self sever:_dismissing];
    }
    _dismissing = nil;
}

- (void)severPending {
    if (_pendingDrop) {
        OTPageFrame *frame = _pendingDrop;
        _pendingDrop = nil;
        [self sever:frame];
    }
}

- (void)sever:(OTPageFrame *)frame {
    JSONObject *data = frame.data;
    OTTemplateContext *context = frame.template;
    if (!context) {
        return;
    }
    [context.rootView removeFromSuperview];
    [context releaseTemplate];
    frame.template = nil;
    frame.data = data;
}

- (void)relayout:(OTPageFrame *)frame {
    if (!frame.template) {
        return;
    }
    [OTEngine.shared relayoutTemplate:frame.template viewport:_container.bounds.size];
    frame.template.rootView.frame = _stage.bounds;
}

- (void)syncBack {
    _host.navigationController.interactivePopGestureRecognizer.enabled = _names.count <= 1;
}

- (NSInteger)nextGeneration {
    _generation += 1;
    return _generation;
}

@end

@implementation OTPageForm

+ (NSArray<UIView *> *)children:(UIView *)view {
    if ([view isKindOfClass:[OTColumnView class]] && ((OTColumnView *)view).scrolling) {
        return ((OTColumnView *)view).scrollContent.templateChildren;
    }
    if ([view isKindOfClass:[OTAbsoluteView class]]) {
        return ((OTAbsoluteView *)view).templateChildren;
    }
    return view.subviews;
}

+ (void)snapshot:(UIView *)root data:(JSONObject *)data {
    if (!root || !data) {
        return;
    }
    [self write:root data:data];
}

+ (void)restore:(UIView *)root data:(JSONObject *)data {
    if (!root || !data) {
        return;
    }
    [self apply:root data:data];
}

+ (void)captureScroll:(UIView *)root into:(NSMutableDictionary<NSString *, NSDictionary *> *)into {
    if (!root || !into) {
        return;
    }
    NSMutableDictionary *found = [NSMutableDictionary dictionary];
    [self readScroll:root path:@"0" into:found];
    [into removeAllObjects];
    [into addEntriesFromDictionary:found];
}

+ (void)restoreScroll:(UIView *)root scrolls:(NSDictionary<NSString *, NSDictionary *> *)scrolls {
    if (!root || scrolls.count == 0) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!root.superview) {
            return;
        }
        [self applyScroll:root path:@"0" scrolls:scrolls];
    });
}

+ (void)write:(UIView *)view data:(JSONObject *)data {
    if ([view isKindOfClass:[OTListView class]] || [view isKindOfClass:[OTItemView class]]) {
        return;
    }
    NSString *identifier = [OTViewMark bind:view].idName;
    if (identifier) {
        if ([view conformsToProtocol:@protocol(OTInputting)]) {
            [OTData setValue:[JSONValue string:((id<OTInputting>)view).textValue] forKey:identifier on:data];
        }
        if ([view conformsToProtocol:@protocol(OTCheckable)]) {
            [OTData setValue:[JSONValue bool:((id<OTCheckable>)view).checked] forKey:identifier on:data];
        }
    }
    for (UIView *child in [self children:view]) {
        [self write:child data:data];
    }
}

+ (void)apply:(UIView *)view data:(JSONObject *)data {
    if ([view isKindOfClass:[OTListView class]] || [view isKindOfClass:[OTItemView class]]) {
        return;
    }
    NSString *identifier = [OTViewMark bind:view].idName;
    JSONValue *value = identifier ? [data get:identifier] : nil;
    if (value) {
        if ([view conformsToProtocol:@protocol(OTInputting)] && value.kind == JSONValueKindString) {
            id<OTInputting> input = (id<OTInputting>)view;
            input.suppressChange = YES;
            input.textValue = value.string ?: @"";
            input.suppressChange = NO;
        }
        if ([view conformsToProtocol:@protocol(OTCheckable)] && value.kind == JSONValueKindBool) {
            [(id<OTCheckable>)view setCheckedSilently:value.boolValue];
        }
    }
    for (UIView *child in [self children:view]) {
        [self apply:child data:data];
    }
}

+ (void)readScroll:(UIView *)view path:(NSString *)path into:(NSMutableDictionary *)into {
    if ([view isKindOfClass:[OTListView class]]) {
        NSDictionary *scroll = [(OTListView *)view firstScroll];
        if (scroll) {
            into[path] = @{@"position": scroll[@"index"] ?: @0, @"offset": scroll[@"offset"] ?: @0};
        }
        return;
    }
    if ([view isKindOfClass:[OTItemView class]]) {
        return;
    }
    NSArray<UIView *> *children = [self children:view];
    [children enumerateObjectsUsingBlock:^(UIView *child, NSUInteger index, BOOL *stop) {
        [self readScroll:child path:[NSString stringWithFormat:@"%@/%lu", path, (unsigned long)index] into:into];
    }];
}

+ (void)applyScroll:(UIView *)view path:(NSString *)path scrolls:(NSDictionary *)scrolls {
    if ([view isKindOfClass:[OTListView class]]) {
        NSDictionary *scroll = scrolls[path];
        if (scroll) {
            [(OTListView *)view restoreScrollIndex:[scroll[@"position"] integerValue] offset:[scroll[@"offset"] doubleValue]];
        }
        return;
    }
    if ([view isKindOfClass:[OTItemView class]]) {
        return;
    }
    NSArray<UIView *> *children = [self children:view];
    [children enumerateObjectsUsingBlock:^(UIView *child, NSUInteger index, BOOL *stop) {
        [self applyScroll:child path:[NSString stringWithFormat:@"%@/%lu", path, (unsigned long)index] scrolls:scrolls];
    }];
}

@end
