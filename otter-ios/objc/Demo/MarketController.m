#import "MarketController.h"
#import "DemoRoutes.h"
#import "NanshiPermissions.h"
#import "../OtterUI/Engine/ExpansionCenter.h"
#import "../OtterUI/Engine/OTBridge.h"
#import "../OtterUI/Nav/PageStack.h"
#import "../OtterUI/Permission/OTPermissionCenter.h"
#import "../OtterUI/Render/OTNodes.h"

static NSString *MarketText(JSONObject *object, NSString *key) {
    if (!object || ![object containsKey:key]) {
        return nil;
    }
    JSONValue *value = [object get:key];
    if (!value || value.kind == JSONValueKindNull) {
        return nil;
    }
    if (value.kind == JSONValueKindString) {
        return value.string ?: @"";
    }
    if (value.kind == JSONValueKindNumber) {
        return value.number.description ?: @"";
    }
    if (value.kind == JSONValueKindBool) {
        return value.boolValue ? @"true" : @"false";
    }
    return @"";
}

static NSNumber *MarketQty(NSString *raw) {
    NSString *text = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
    if (text.length == 0) {
        return nil;
    }
    NSScanner *scanner = [NSScanner scannerWithString:text];
    NSInteger whole = 0;
    if ([scanner scanInteger:&whole] && scanner.isAtEnd) {
        return @(whole);
    }
    scanner = [NSScanner scannerWithString:text];
    double number = 0;
    if ([scanner scanDouble:&number] && scanner.isAtEnd) {
        return @((NSInteger)number);
    }
    return nil;
}

@interface MarketSession : NSObject
@property (nonatomic, strong, nullable) PageStack *stack;
@property (nonatomic, copy) NSArray *stacks;
@property (nonatomic, strong) JSONArray *shops;
@property (nonatomic, copy, nullable) void (^openTab)(NSString *page);
+ (void)activate:(MarketSession *)session;
- (void)releaseSession;
@end

static MarketSession *MarketCurrent;

@implementation MarketSession

+ (void)activate:(MarketSession *)session {
    MarketCurrent = session;
    ExpansionCenter *center = ExpansionCenter.shared;
    [center registerHostAction:@"pay" action:^(UIView *view, JSONObject *params) {
        [MarketCurrent pay:view params:params];
    }];
    [center registerHostAction:@"setQty" action:^(UIView *view, JSONObject *params) {
        [MarketCurrent setQty:params];
    }];
    [center registerHostAction:@"removeLine" action:^(UIView *view, JSONObject *params) {
        [MarketCurrent removeLine:params];
    }];
    [center registerHostAction:@"refreshStatus" action:^(UIView *view, JSONObject *params) {
        [MarketCurrent refreshStatus:view];
    }];
    [center registerHostAction:@"call" action:^(UIView *view, JSONObject *params) {
        [MarketCurrent callShop:view params:params];
    }];
    [center registerHostAction:@"filter" action:^(UIView *view, JSONObject *params) {
        [MarketCurrent filter:params];
    }];
    [center registerHostAction:@"openTab" action:^(UIView *view, JSONObject *params) {
        NSString *page = MarketText(params, @"page");
        if (!page) {
            return;
        }
        if (MarketCurrent.openTab) {
            MarketCurrent.openTab(page);
        }
    }];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _stacks = @[];
        _shops = [JSONArray new];
    }
    return self;
}

- (void)releaseSession {
    if (MarketCurrent == self) {
        MarketCurrent = nil;
        for (NSString *name in @[@"pay", @"setQty", @"removeLine", @"refreshStatus", @"call", @"filter", @"openTab"]) {
            [ExpansionCenter.shared unregisterHostAction:name];
        }
    }
    self.openTab = nil;
    for (id stack in self.stacks) {
        if ([stack isKindOfClass:[PageStack class]]) {
            [stack releaseStack];
        }
    }
    self.stacks = @[];
    self.stack = nil;
    self.shops = [JSONArray new];
}

- (void)pay:(UIView *)view params:(JSONObject *)params {
    UIViewController *activity = view.ot_controller;
    PageStack *paying = self.stack;
    if (!activity || !paying || activity.isBeingDismissed) {
        return;
    }
    NSString *amount = MarketText(params, @"amount") ?: @"";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认支付" message:amount preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        JSONObject *payload = [JSONObject new];
        [payload set:[JSONValue string:[self nextOrderNo]] forKey:@"orderNo"];
        [payload set:[JSONValue string:amount] forKey:@"amount"];
        [paying replace:@"result" raw:payload item:nil pageData:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [activity presentViewController:alert animated:YES completion:nil];
}

- (void)setQty:(JSONObject *)params {
    PageStack *currentStack = self.stack;
    NSString *lineId = MarketText(params, @"lineId");
    NSNumber *qty = MarketQty(MarketText(params, @"qty"));
    if (!currentStack || lineId.length == 0 || !qty) {
        return;
    }
    [currentStack editCurrentData:^(JSONObject *data) {
        JSONArray *lines = [data getJSONArray:@"lines"];
        if (!lines) {
            return;
        }
        for (NSInteger index = 0; index < lines.size; index++) {
            JSONObject *line = [lines getJSONObject:index];
            if ([[line getString:@"lineId"] isEqualToString:lineId]) {
                [self applyQty:line qty:qty.integerValue];
                break;
            }
        }
        [self writeTotal:data lines:lines];
    }];
    [currentStack rebindCurrent];
}

- (void)removeLine:(JSONObject *)params {
    PageStack *currentStack = self.stack;
    NSString *lineId = MarketText(params, @"lineId");
    if (!currentStack || lineId.length == 0) {
        return;
    }
    [currentStack editCurrentData:^(JSONObject *data) {
        JSONArray *lines = [data getJSONArray:@"lines"];
        if (!lines) {
            return;
        }
        JSONArray *kept = [JSONArray new];
        for (NSInteger index = 0; index < lines.size; index++) {
            JSONObject *line = [lines getJSONObject:index];
            if (line && ![[line getString:@"lineId"] isEqualToString:lineId]) {
                [kept add:[JSONValue object:line]];
            }
        }
        [data set:[JSONValue array:kept] forKey:@"lines"];
        [self writeTotal:data lines:kept];
    }];
    [currentStack rebindCurrent];
}

- (void)refreshStatus:(UIView *)view {
    PageStack *currentStack = self.stack;
    if (!currentStack) {
        return;
    }
    [currentStack editCurrentData:^(JSONObject *data) {
        JSONArray *orders = [data getJSONArray:@"orders"];
        JSONObject *first = orders.size > 0 ? [orders getJSONObject:0] : nil;
        if (first && [[first getString:@"status"] isEqualToString:@"制作中"]) {
            [first set:[JSONValue string:@"可取餐"] forKey:@"status"];
            [first set:[JSONValue string:@"可以到柜台取了，手冲还是热的。"] forKey:@"statusNote"];
        }
    }];
    [currentStack rebindCurrent];
    if (!view.ot_controller.isBeingDismissed) {
        [OTToast show:@"订单状态已更新" inView:view];
    }
}

- (void)callShop:(UIView *)view params:(JSONObject *)params {
    if (view.ot_controller.isBeingDismissed) {
        return;
    }
    NSString *phone = MarketText(params, @"phone") ?: @"";
    if (![self phoneLooksDialable:phone]) {
        [OTToast show:@"这个号码不能拨" inView:view];
        return;
    }
    [OTToast show:[NSString stringWithFormat:@"正在联系店铺 %@", phone] inView:view];
}

- (BOOL)phoneLooksDialable:(NSString *)phone {
    if (phone.length < 6 || phone.length > 20) {
        return NO;
    }
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"0123456789+()- "];
    return [phone rangeOfCharacterFromSet:allowed.invertedSet].location == NSNotFound;
}

- (void)filter:(JSONObject *)params {
    PageStack *currentStack = self.stack;
    if (!currentStack) {
        return;
    }
    NSString *query = [(MarketText(params, @"query") ?: @"") stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    JSONArray *source = self.shops;
    [currentStack editCurrentData:^(JSONObject *data) {
        JSONArray *filtered = [JSONArray new];
        for (NSInteger index = 0; index < source.size; index++) {
            JSONObject *shop = [source getJSONObject:index];
            NSString *name = [shop getString:@"name"] ?: @"";
            if (shop && (query.length == 0 || [name containsString:query])) {
                JSONObject *copy = [OTData deepCopy:shop];
                if (copy) {
                    [filtered add:[JSONValue object:copy]];
                }
            }
        }
        [data set:[JSONValue array:filtered] forKey:@"shops"];
        [data set:[JSONValue string:query] forKey:@"query"];
        [data set:[JSONValue bool:(query.length > 0 && filtered.size == 0)] forKey:@"noResult"];
    }];
    [currentStack rebindCurrent];
}

- (void)applyQty:(JSONObject *)line qty:(NSInteger)qty {
    NSInteger safe = qty < 1 ? 1 : qty;
    NSInteger amount = [OTData intValue:line key:@"price"] * safe;
    [line set:[JSONValue number:[JSONNumber intNumber:safe]] forKey:@"qty"];
    [line set:[JSONValue string:[NSString stringWithFormat:@"%ld", (long)safe]] forKey:@"qtyText"];
    [line set:[JSONValue string:[NSString stringWithFormat:@"%ld", (long)(safe > 1 ? safe - 1 : 1)]] forKey:@"qtyMinus"];
    [line set:[JSONValue string:[NSString stringWithFormat:@"%ld", (long)(safe + 1)]] forKey:@"qtyPlus"];
    [line set:[JSONValue string:[NSString stringWithFormat:@"%ld", (long)amount]] forKey:@"amount"];
}

- (void)writeTotal:(JSONObject *)data lines:(JSONArray *)lines {
    NSInteger total = 0;
    for (NSInteger index = 0; index < lines.size; index++) {
        JSONObject *line = [lines getJSONObject:index];
        if (!line) {
            continue;
        }
        total += [OTData intValue:line key:@"price"] * [OTData intValue:line key:@"qty"];
    }
    [data set:[JSONValue string:[NSString stringWithFormat:@"%ld", (long)total]] forKey:@"total"];
    [data set:[JSONValue string:[NSString stringWithFormat:@"%ld 元", (long)total]] forKey:@"totalLabel"];
    [data set:[JSONValue bool:lines.size == 0] forKey:@"empty"];
}

- (NSString *)nextOrderNo {
    long long tail = ((long long)([NSDate date].timeIntervalSince1970 * 1000.0)) % 1000000;
    if (tail < 0) {
        tail += 1000000;
    }
    return [NSString stringWithFormat:@"NS%06lld", tail];
}

@end

@interface MarketController () <UIGestureRecognizerDelegate>
@end

@implementation MarketController {
    MarketSession *_session;
    OTPermissionCenter *_permissions;
    NSDictionary<NSString *, UIView *> *_containers;
    NSArray<NSString *> *_pages;
    NSArray<UILabel *> *_labels;
    NSArray<UIView *> *_marks;
    UIView *_tabBar;
    UIView *_divider;
    NSInteger _selected;
    CGFloat _keyboard;
    UIScreenEdgePanGestureRecognizer *_homeEdge;
    id<UIGestureRecognizerDelegate> _savedPopDelegate;
    UIColor *_accent;
    UIColor *_muted;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _accent = [UIColor colorWithRed:0x8B / 255.0 green:0x57 / 255.0 blue:0x2A / 255.0 alpha:1];
    _muted = [UIColor colorWithRed:0x8A / 255.0 green:0x81 / 255.0 blue:0x78 / 255.0 alpha:1];
    _pages = @[@"home", @"orders", @"mine"];
    _session = [MarketSession new];
    self.view.backgroundColor = [UIColor colorWithRed:0xF6 / 255.0 green:0xF1 / 255.0 blue:0xEA / 255.0 alpha:1];
    DemoTopBar *bar = [DemoTopBar barWithTitle:@"南市" showsBack:YES];
    __weak MarketController *barOwner = self;
    bar.onBack = ^{
        [DemoRoutes goBack:barOwner];
    };
    [self.view addSubview:bar];
    _permissions = [OTPermissionCenter installWithHost:self prompts:[NanshiPermissions prompts]];
    UIView *home = [UIView new];
    UIView *orders = [UIView new];
    UIView *mine = [UIView new];
    orders.hidden = YES;
    mine.hidden = YES;
    _containers = @{@"home": home, @"orders": orders, @"mine": mine};
    for (NSString *name in _pages) {
        [self.view addSubview:_containers[name]];
    }
    [self buildTabBar];
    _session.shops = [self readShops];
    __weak MarketController *weakSelf = self;
    _session.openTab = ^(NSString *page) {
        NSNumber *index = @{@"home": @0, @"orders": @1, @"mine": @2}[page];
        if (index) {
            [weakSelf showTab:page index:index.integerValue];
        }
    };
    [MarketSession activate:_session];
    NSError *error = nil;
    PageStack *homeStack = [PageStack attachWithHost:self insetRoot:self.view container:home routePath:@"templates/market/routes.json" bizId:@"demo" templateId:@"market" error:&error];
    PageStack *ordersStack = [PageStack attachWithHost:self insetRoot:self.view container:orders routePath:@"templates/market/routes-orders.json" bizId:@"demo" templateId:@"market" error:&error];
    PageStack *mineStack = [PageStack attachWithHost:self insetRoot:self.view container:mine routePath:@"templates/market/routes-mine.json" bizId:@"demo" templateId:@"market" error:&error];
    NSMutableArray *stacks = [NSMutableArray arrayWithObjects:homeStack ?: [NSNull null], ordersStack ?: [NSNull null], mineStack ?: [NSNull null], nil];
    _session.stacks = stacks;
    _session.stack = homeStack;
    [homeStack activate];
    homeStack.onInsets = ^{
        [weakSelf.view setNeedsLayout];
    };
    _homeEdge = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(homeEdge:)];
    _homeEdge.edges = self.view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft ? UIRectEdgeRight : UIRectEdgeLeft;
    _homeEdge.delegate = self;
    [self.view addGestureRecognizer:_homeEdge];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboard:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [self paintTabs];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)buildTabBar {
    _tabBar = [UIView new];
    _tabBar.backgroundColor = UIColor.whiteColor;
    [self.view addSubview:_tabBar];
    _divider = [UIView new];
    _divider.backgroundColor = [UIColor colorWithRed:0xE6 / 255.0 green:0xDD / 255.0 blue:0xD2 / 255.0 alpha:1];
    [_tabBar addSubview:_divider];
    NSArray<NSString *> *titles = @[@"首页", @"订单", @"我的"];
    NSMutableArray<UILabel *> *labels = [NSMutableArray array];
    NSMutableArray<UIView *> *marks = [NSMutableArray array];
    [titles enumerateObjectsUsingBlock:^(NSString *title, NSUInteger index, BOOL *stop) {
        UIControl *tap = [UIControl new];
        tap.tag = (NSInteger)index;
        [tap addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_tabBar addSubview:tap];
        UILabel *label = [UILabel new];
        label.text = title;
        label.textAlignment = NSTextAlignmentCenter;
        label.font = [UIFont systemFontOfSize:14];
        [_tabBar addSubview:label];
        UIView *mark = [UIView new];
        mark.backgroundColor = _accent;
        mark.layer.cornerRadius = 2;
        [_tabBar addSubview:mark];
        [labels addObject:label];
        [marks addObject:mark];
    }];
    _labels = labels;
    _marks = marks;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    UIGestureRecognizer *pop = self.navigationController.interactivePopGestureRecognizer;
    if (pop.delegate != self) {
        _savedPopDelegate = pop.delegate;
        pop.delegate = self;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    UIGestureRecognizer *pop = self.navigationController.interactivePopGestureRecognizer;
    if (pop.delegate != self) {
        return;
    }
    id<UIGestureRecognizerDelegate> saved = _savedPopDelegate;
    if (self.isMovingFromParentViewController && self.transitionCoordinator) {
        [self.transitionCoordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            if (!context.isCancelled && pop.delegate == self) {
                pop.delegate = saved;
            }
        }];
        return;
    }
    pop.delegate = saved;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIEdgeInsets safe = self.view.safeAreaInsets;
    CGFloat bottom = MAX(safe.bottom, _keyboard);
    UIFont *font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    CGFloat labelHeight = ceil([@"首页" sizeWithAttributes:@{NSFontAttributeName: font}].height);
    CGFloat rowHeight = 10 + labelHeight + 4 + 3 + 8;
    CGFloat tabHeight = 1 + rowHeight;
    CGFloat width = self.view.bounds.size.width;
    DemoTopBar *bar = nil;
    for (UIView *child in self.view.subviews) {
        if ([child isKindOfClass:[DemoTopBar class]]) {
            bar = (DemoTopBar *)child;
            break;
        }
    }
    CGFloat topHeight = bar ? [DemoTopBar barHeight] : 0;
    if (bar) {
        bar.frame = CGRectMake(safe.left, safe.top, MAX(width - safe.left - safe.right, 0), topHeight);
        [self.view bringSubviewToFront:bar];
    }
    CGFloat tabWidth = MAX(width - safe.left - safe.right, 0);
    _tabBar.frame = CGRectMake(safe.left, self.view.bounds.size.height - bottom - tabHeight, tabWidth, tabHeight);
    _divider.frame = CGRectMake(0, 0, tabWidth, 1);
    CGFloat column = tabWidth / 3.0;
    NSArray<UIControl *> *taps = [_tabBar.subviews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UIView *view, NSDictionary *bindings) {
        return [view isKindOfClass:[UIControl class]];
    }]];
    for (NSInteger index = 0; index < 3; index++) {
        CGFloat x = column * index;
        for (UIControl *tap in taps) {
            if (tap.tag == index) {
                tap.frame = CGRectMake(x, 1, column, rowHeight);
            }
        }
        _labels[index].frame = CGRectMake(x, 1 + 10, column, labelHeight);
        _marks[index].frame = CGRectMake(x + (column - 18) / 2.0, 1 + 10 + labelHeight + 4, 18, 3);
    }
    CGFloat contentTop = safe.top + topHeight;
    CGRect content = CGRectMake(safe.left, contentTop, MAX(width - safe.left - safe.right, 0), MAX(CGRectGetMinY(_tabBar.frame) - contentTop, 0));
    for (UIView *container in _containers.allValues) {
        container.frame = content;
    }
    for (id stack in _session.stacks) {
        if ([stack isKindOfClass:[PageStack class]]) {
            [stack layoutContainers];
        }
    }
    [self paintTabs];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.isMovingFromParentViewController || self.isBeingDismissed) {
        [_permissions releaseCenter];
        _permissions = nil;
        [_session releaseSession];
    }
}

- (void)tabTapped:(UIControl *)sender {
    if (sender.tag < 0 || sender.tag >= (NSInteger)_pages.count) {
        return;
    }
    [self showTab:_pages[sender.tag] index:sender.tag];
}

- (void)showTab:(NSString *)page index:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_session.stacks.count) {
        return;
    }
    id slot = _session.stacks[index];
    if (![slot isKindOfClass:[PageStack class]]) {
        return;
    }
    PageStack *target = slot;
    _session.stack = target;
    [target activate];
    [_containers enumerateKeysAndObjectsUsingBlock:^(NSString *name, UIView *view, BOOL *stop) {
        BOOL show = [name isEqualToString:page];
        if (!show) {
            [view endEditing:YES];
        }
        view.hidden = !show;
    }];
    _selected = index;
    [self paintTabs];
    if ([page isEqualToString:@"mine"]) {
        [_permissions publishAll:_containers[@"mine"] ?: self.view];
    }
}

- (void)paintTabs {
    [_labels enumerateObjectsUsingBlock:^(UILabel *label, NSUInteger index, BOOL *stop) {
        BOOL selected = (NSInteger)index == _selected;
        label.textColor = selected ? _accent : _muted;
        label.font = [UIFont systemFontOfSize:14 weight:selected ? UIFontWeightBold : UIFontWeightRegular];
        _marks[index].hidden = !selected;
    }];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    NSInteger depth = _session.stack.depth;
    if (gestureRecognizer == self.navigationController.interactivePopGestureRecognizer) {
        return _selected == 0 && depth <= 1;
    }
    if (gestureRecognizer == _homeEdge) {
        return _selected != 0 && depth <= 1;
    }
    return YES;
}

- (void)homeEdge:(UIScreenEdgePanGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded) {
        return;
    }
    if (_selected != 0 && _session.stack.depth <= 1) {
        [self showTab:@"home" index:0];
    }
}

- (void)keyboard:(NSNotification *)note {
    NSValue *value = note.userInfo[UIKeyboardFrameEndUserInfoKey];
    if (![value isKindOfClass:[NSValue class]]) {
        return;
    }
    CGRect frame = [self.view convertRect:value.CGRectValue fromView:nil];
    CGRect overlap = CGRectIntersection(self.view.bounds, frame);
    CGFloat height = CGRectIsNull(overlap) ? 0 : overlap.size.height;
    _keyboard = frame.origin.y >= CGRectGetMaxY(self.view.bounds) - 1 ? 0 : height;
    [self.view setNeedsLayout];
}

- (JSONArray *)readShops {
    NSString *text = [OTAssets text:@"templates/market/mock-data/home.json" error:nil];
    JSONObject *root = text ? [OTData parseObject:text error:nil] : nil;
    JSONArray *shops = [root getJSONArray:@"shops"];
    if (!shops) {
        return [JSONArray new];
    }
    JSONObject *holder = [JSONObject new];
    [holder set:[JSONValue array:shops] forKey:@"shops"];
    return [[OTData deepCopy:holder] getJSONArray:@"shops"] ?: [JSONArray new];
}

@end
