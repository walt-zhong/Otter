#import "OTNodes.h"
#import "OTEvents.h"
#import "OTViewTree.h"
#import "OTStyle.h"
#import "../Engine/OTEngine.h"
#import "../Engine/OTBridge.h"
#import "../Engine/ExpansionCenter.h"
#import <math.h>
#import <objc/runtime.h>

static char OTBindKey;

@implementation OTBind
@end

@implementation OTViewMark

+ (OTBind *)bind:(UIView *)view {
    OTBind *existing = objc_getAssociatedObject(view, &OTBindKey);
    if (existing) {
        return existing;
    }
    OTBind *created = [OTBind new];
    created.clickNames = @[];
    created.changeNames = @[];
    created.fields = @{};
    created.scale = 1;
    created.radii = @[];
    objc_setAssociatedObject(view, &OTBindKey, created, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return created;
}

@end

@implementation OTClickGate

+ (OTClickGate *)shared {
    static OTClickGate *gate;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ gate = [OTClickGate new]; });
    return gate;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    UIView *host = gestureRecognizer.view;
    if (!host) {
        return YES;
    }
    UIView *view = touch.view;
    while (view && view != host) {
        if ([view isKindOfClass:[UIControl class]]) {
            return NO;
        }
        if ([OTViewMark bind:view].hasClick) {
            return NO;
        }
        view = view.superview;
    }
    return YES;
}

@end

@implementation OTAbsoluteView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _templateChildren = [NSMutableArray array];
    }
    return self;
}

- (void)placeChildren {
    for (UIView *child in self.templateChildren) {
        if (!child.hidden) {
            child.frame = [OTViewMark bind:child].otterFrame;
        }
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self placeChildren];
    for (CALayer *layer in self.layer.sublayers) {
        if ([layer.name isEqualToString:@"otter.gradient"]) {
            layer.frame = self.bounds;
        }
    }
    NSArray<NSNumber *> *radii = [OTViewMark bind:self].radii;
    if (radii.count == 4) {
        BOOL any = NO;
        BOOL same = YES;
        for (NSNumber *radius in radii) {
            if (radius.doubleValue > 0) any = YES;
            if (fabs(radius.doubleValue - radii[0].doubleValue) >= 0.5) same = NO;
        }
        if (any && !same) {
            CAShapeLayer *mask = [CAShapeLayer layer];
            mask.path = [OTChrome cornerPath:self.bounds radii:radii].CGPath;
            self.layer.mask = mask;
        }
    }
    [OTGlassLayer layout:self];
}

@end

@implementation OTColumnView {
    UIScrollView *_scroller;
    UIImageView *_backdrop;
    CGFloat _panOffset;
    CADisplayLink *_panDisplay;
    CGFloat _panVelocity;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _scrollContent = [OTAbsoluteView new];
        _backdrop = [UIImageView new];
        _backdrop.contentMode = UIViewContentModeScaleAspectFill;
        _backdrop.clipsToBounds = YES;
        _backdrop.userInteractionEnabled = NO;
        self.clipsToBounds = YES;
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panBackdrop:)];
        pan.delegate = self;
        [self addGestureRecognizer:pan];
    }
    return self;
}

- (void)ensureScroll {
    if (_scrolling) {
        return;
    }
    _scrolling = YES;
    _scroller = [UIScrollView new];
    _scroller.frame = self.bounds;
    _scroller.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scroller.alwaysBounceVertical = YES;
    _scroller.clipsToBounds = YES;
    _scroller.backgroundColor = UIColor.clearColor;
    _scrollContent.backgroundColor = UIColor.clearColor;
    [self addSubview:_scroller];
    [_scroller addSubview:_scrollContent];
}

- (void)placeChildren {
    NSArray<UIView *> *children = _scrolling ? _scrollContent.templateChildren : self.templateChildren;
    UIView *host = _scrolling ? _scrollContent : self;
    CGFloat bottom = 0;
    CGFloat right = 0;
    for (UIView *child in children) {
        if (child.hidden) {
            continue;
        }
        if (child.superview != host) {
            [host addSubview:child];
        }
        child.frame = [OTViewMark bind:child].otterFrame;
        bottom = MAX(bottom, CGRectGetMaxY(child.frame));
        right = MAX(right, CGRectGetMaxX(child.frame));
    }
    if (_scrolling) {
        _scroller.frame = self.bounds;
        CGSize size = CGSizeMake(MAX(self.bounds.size.width, right), MAX(bottom, self.bounds.size.height));
        _scrollContent.frame = CGRectMake(0, 0, size.width, size.height);
        _scroller.contentSize = size;
    }
    [self layoutBackdrop];
}

- (void)showBackdropNamed:(NSString *)name {
    UIImage *image = [OTAssets imageNamed:name];
    if (!image) {
        return;
    }
    _backdrop.image = image;
    if (!_backdrop.superview) {
        [self insertSubview:_backdrop atIndex:0];
    }
    _panOffset = 0;
    [self layoutBackdrop];
}

- (void)clearBackdrop {
    _backdrop.image = nil;
    [_backdrop removeFromSuperview];
}

- (void)layoutBackdrop {
    UIImage *image = _backdrop.image;
    if (!image || self.bounds.size.width <= 0) {
        return;
    }
    CGFloat fitted = self.bounds.size.width * image.size.height / MAX(image.size.width, 1);
    if (fitted > self.bounds.size.height + 1) {
        CGFloat maxOffset = fitted - self.bounds.size.height;
        _panOffset = MIN(MAX(_panOffset, 0), maxOffset);
        _backdrop.frame = CGRectMake(0, -_panOffset, self.bounds.size.width, fitted);
        _backdrop.contentMode = UIViewContentModeScaleToFill;
    } else {
        _backdrop.frame = self.bounds;
        _backdrop.contentMode = UIViewContentModeScaleAspectFill;
    }
}

- (CGFloat)maxPan {
    UIImage *image = _backdrop.image;
    if (!image || self.bounds.size.width <= 0) {
        return 0;
    }
    CGFloat fitted = self.bounds.size.width * image.size.height / MAX(image.size.width, 1);
    return MAX(fitted - self.bounds.size.height, 0);
}

- (void)panBackdrop:(UIPanGestureRecognizer *)gesture {
    if ([self maxPan] <= 0) {
        return;
    }
    CGPoint translation = [gesture translationInView:self];
    if (gesture.state == UIGestureRecognizerStateChanged) {
        _panOffset = MIN(MAX(_panOffset - translation.y, 0), [self maxPan]);
        [gesture setTranslation:CGPointZero inView:self];
        [self layoutBackdrop];
    } else if (gesture.state == UIGestureRecognizerStateEnded) {
        _panVelocity = -[gesture velocityInView:self].y;
        [self startFling];
    }
}

- (void)startFling {
    [_panDisplay invalidate];
    _panDisplay = [CADisplayLink displayLinkWithTarget:self selector:@selector(stepFling)];
    [_panDisplay addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)stepFling {
    _panOffset = MIN(MAX(_panOffset + _panVelocity * (1.0 / 60.0), 0), [self maxPan]);
    _panVelocity *= 0.95;
    [self layoutBackdrop];
    if (fabs(_panVelocity) < 8 || _panOffset == 0 || _panOffset == [self maxPan]) {
        [_panDisplay invalidate];
        _panDisplay = nil;
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (![gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        return YES;
    }
    if ([self maxPan] <= 0) {
        return NO;
    }
    CGPoint velocity = [(UIPanGestureRecognizer *)gestureRecognizer velocityInView:self];
    return fabs(velocity.y) > fabs(velocity.x);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return NO;
}

@end

@implementation OTRowView
@end

@implementation OTTextView

- (void)drawTextInRect:(CGRect)rect {
    CGRect textRect = UIEdgeInsetsInsetRect(rect, self.textInset);
    // The layout box is the ceil of one line. UILabel still wraps the tail
    // onto a second line when that line is only a fraction wider than the
    // box, and the one-line height clips it. Draw the line ourselves when
    // the whole string fits. Real wrapping stays with UILabel.
    if (self.numberOfLines != 1 && self.lineBreakMode != NSLineBreakByTruncatingTail && self.text.length > 0 && self.font) {
        CGSize fit = [self.text sizeWithAttributes:@{NSFontAttributeName: self.font}];
        if (fit.width <= textRect.size.width + 1) {
            NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
            style.alignment = self.textAlignment;
            style.lineBreakMode = NSLineBreakByClipping;
            UIColor *color = self.textColor ?: UIColor.blackColor;
            [self.text drawInRect:textRect withAttributes:@{
                NSFontAttributeName: self.font,
                NSForegroundColorAttributeName: color,
                NSParagraphStyleAttributeName: style
            }];
            return;
        }
    }
    [super drawTextInRect:textRect];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    for (CALayer *layer in self.layer.sublayers) {
        if ([layer.name isEqualToString:@"otter.gradient"]) {
            layer.frame = self.bounds;
        }
    }
}

@end

@implementation OTImageView {
    NSURLSessionDataTask *_task;
}

- (void)load:(NSString *)src {
    [_task cancel];
    _task = nil;
    if ([self.fit isEqualToString:@"contain"]) {
        self.contentMode = UIViewContentModeScaleAspectFit;
    } else if ([self.fit isEqualToString:@"fill"]) {
        self.contentMode = UIViewContentModeScaleToFill;
    } else {
        self.contentMode = UIViewContentModeScaleAspectFill;
    }
    self.clipsToBounds = YES;
    self.backgroundColor = self.placeholder;
    NSString *trimmed = [src stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        self.image = nil;
        return;
    }
    if ([trimmed hasPrefix:@"http://"] || [trimmed hasPrefix:@"https://"]) {
        NSURL *url = [NSURL URLWithString:trimmed];
        if (!url) {
            self.image = nil;
            return;
        }
        __weak OTImageView *current = self;
        _task = [NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            UIImage *image = data ? [UIImage imageWithData:data] : nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                OTImageView *imageView = current;
                if (imageView && imageView->_task) {
                    imageView.image = image;
                }
            });
        }];
        [_task resume];
        return;
    }
    if ([trimmed hasPrefix:@"res:"]) {
        self.image = [OTAssets imageNamed:[trimmed substringFromIndex:4]];
        return;
    }
    if ([trimmed hasPrefix:@"content:"]) {
        NSString *rest = [trimmed substringFromIndex:@"content:".length];
        if ([rest hasPrefix:@"file:"]) {
            self.image = [UIImage imageWithContentsOfFile:[NSURL URLWithString:rest].path];
        } else {
            self.image = [UIImage imageWithContentsOfFile:rest];
        }
        return;
    }
    self.image = nil;
}

- (void)releaseImage {
    [_task cancel];
    _task = nil;
    self.image = nil;
}

@end

@implementation OTSpacerView
@end

@implementation OTInputView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.borderStyle = UITextBorderStyleNone;
        [self addTarget:self action:@selector(changed) forControlEvents:UIControlEventEditingChanged];
        self.delegate = self;
        self.returnKeyType = UIReturnKeyDone;
    }
    return self;
}

- (NSString *)textValue {
    return self.text ?: @"";
}

- (void)setTextValue:(NSString *)textValue {
    if ([self.text isEqualToString:textValue]) {
        return;
    }
    self.suppressChange = YES;
    self.text = textValue;
    self.suppressChange = NO;
}

- (void)changed {
    if (self.suppressChange) {
        return;
    }
    OTBind *bind = [OTViewMark bind:self];
    JSONObject *data = bind.itemData ?: bind.template.data;
    if (bind.idName && data) {
        [OTData setValue:[JSONValue string:self.textValue] forKey:bind.idName on:data];
    }
    [OTEvents fireChange:self];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (!self.maxLength || !textField.text) {
        return YES;
    }
    NSString *next = [textField.text stringByReplacingCharactersInRange:range withString:string];
    return (NSInteger)next.length <= self.maxLength.integerValue;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [OTIme dismiss:self];
    return YES;
}

@end

@implementation OTInputArea

- (instancetype)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)textContainer {
    self = [super initWithFrame:frame textContainer:textContainer];
    if (self) {
        self.delegate = self;
        self.backgroundColor = UIColor.clearColor;
        self.textContainerInset = UIEdgeInsetsZero;
        self.textContainer.lineFragmentPadding = 0;
    }
    return self;
}

- (NSString *)textValue {
    return self.text ?: @"";
}

- (void)setTextValue:(NSString *)textValue {
    if ([self.text isEqualToString:textValue]) {
        return;
    }
    self.suppressChange = YES;
    self.text = textValue;
    self.suppressChange = NO;
}

- (void)textViewDidChange:(UITextView *)textView {
    if (self.suppressChange) {
        return;
    }
    OTBind *bind = [OTViewMark bind:self];
    JSONObject *data = bind.itemData ?: bind.template.data;
    if (bind.idName && data) {
        [OTData setValue:[JSONValue string:self.textValue] forKey:bind.idName on:data];
    }
    [OTEvents fireChange:self];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if (!self.maxLength || !textView.text) {
        return YES;
    }
    return (NSInteger)[textView.text stringByReplacingCharactersInRange:range withString:text].length <= self.maxLength.integerValue;
}

@end

@interface OTCheckView ()
@property (nonatomic, assign) BOOL checked;
@end

@implementation OTCheckView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _box = [UIView new];
        _box.userInteractionEnabled = NO;
        _label = [UILabel new];
        _label.userInteractionEnabled = NO;
        [self addSubview:_box];
        [self addSubview:_label];
        _mark = [CAShapeLayer layer];
        [_box.layer addSublayer:_mark];
        _mark.fillColor = nil;
        _mark.lineWidth = 2;
        _mark.lineCap = kCALineCapRound;
        _mark.lineJoin = kCALineJoinRound;
        [self addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)setCheckedSilently:(BOOL)value {
    _checked = value;
    [self setNeedsLayout];
}

- (void)toggle {
    [self setCheckedSilently:!self.checked];
    [self writeBack];
    [OTEvents fireChange:self];
}

- (void)writeBack {
    OTBind *bind = [OTViewMark bind:self];
    JSONObject *data = bind.itemData ?: bind.template.data;
    if (bind.idName && data) {
        [OTData setValue:[JSONValue bool:self.checked] forKey:bind.idName on:data];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat side = 18;
    _box.frame = CGRectMake(0, (self.bounds.size.height - side) / 2, side, side);
    _box.layer.cornerRadius = 4;
    _label.frame = CGRectMake(side + 8, 0, MAX(self.bounds.size.width - side - 8, 0), self.bounds.size.height);
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(4, 9)];
    [path addLineToPoint:CGPointMake(8, 13)];
    [path addLineToPoint:CGPointMake(14, 5)];
    _mark.path = path.CGPath;
    _mark.frame = _box.bounds;
    _mark.hidden = !self.checked;
}

@end

@interface OTRadioView ()
@property (nonatomic, assign) BOOL checked;
@end

@implementation OTRadioView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _dot = [UIView new];
        _dot.userInteractionEnabled = NO;
        _label = [UILabel new];
        _label.userInteractionEnabled = NO;
        _groupName = @"";
        [self addSubview:_dot];
        [self addSubview:_label];
        [self addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)setCheckedSilently:(BOOL)value {
    _checked = value;
    [self setNeedsLayout];
}

- (void)toggle {
    [self setCheckedSilently:YES];
    [self claimGroup];
    [self writeAll];
    [OTEvents fireChange:self];
}

- (void)claimGroup {
    if (self.groupName.length == 0) {
        return;
    }
    [self clear:[self scope]];
}

- (void)clear:(UIView *)view {
    if ([view isKindOfClass:[OTRadioView class]]) {
        OTRadioView *radio = (OTRadioView *)view;
        if (radio != self && [radio.groupName isEqualToString:self.groupName] && radio.checked) {
            [radio setCheckedSilently:NO];
        }
    }
    for (UIView *child in view.subviews) {
        [self clear:child];
    }
}

- (void)writeAll {
    [self writeTree:[self scope]];
}

- (void)writeTree:(UIView *)view {
    if ([view isKindOfClass:[OTRadioView class]]) {
        OTRadioView *radio = (OTRadioView *)view;
        if ([radio.groupName isEqualToString:self.groupName]) {
            [radio writeSelf];
        }
    }
    if ([view isKindOfClass:[OTListView class]] || [view isKindOfClass:[OTItemView class]]) {
        return;
    }
    for (UIView *child in view.subviews) {
        [self writeTree:child];
    }
}

- (void)writeSelf {
    OTBind *bind = [OTViewMark bind:self];
    JSONObject *data = bind.itemData ?: bind.template.data;
    if (bind.idName && data) {
        [OTData setValue:[JSONValue bool:self.checked] forKey:bind.idName on:data];
    }
}

- (UIView *)scope {
    UIView *current = self;
    while (current.superview) {
        if ([current.superview isKindOfClass:[OTItemView class]]) {
            return current.superview;
        }
        current = current.superview;
    }
    return current;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat side = 18;
    _dot.frame = CGRectMake(0, (self.bounds.size.height - side) / 2, side, side);
    _dot.layer.cornerRadius = side / 2;
    _dot.layer.borderWidth = self.checked ? 5 : 1.5;
    _label.frame = CGRectMake(side + 8, 0, MAX(self.bounds.size.width - side - 8, 0), self.bounds.size.height);
}

@end

@implementation OTItemView
@end

@implementation OTSwitchView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _track = [UISwitch new];
        [_track addTarget:self action:@selector(toggled) forControlEvents:UIControlEventValueChanged];
        _label = [UILabel new];
        _label.userInteractionEnabled = NO;
        [self addSubview:_track];
        [self addSubview:_label];
    }
    return self;
}

- (BOOL)checked {
    return _track.on;
}

- (void)setCheckedSilently:(BOOL)value {
    [_track setOn:value animated:NO];
}

- (void)toggled {
    [self writeBack];
    [OTEvents fireChange:self];
}

- (void)writeBack {
    OTBind *bind = [OTViewMark bind:self];
    JSONObject *data = bind.itemData ?: bind.template.data;
    if (bind.idName && data) {
        [OTData setValue:[JSONValue bool:_track.on] forKey:bind.idName on:data];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize size = _track.intrinsicContentSize;
    _track.frame = CGRectMake(0, (self.bounds.size.height - size.height) / 2, size.width, size.height);
    _label.frame = CGRectMake(size.width + 8, 0, MAX(self.bounds.size.width - size.width - 8, 0), self.bounds.size.height);
}

@end

@implementation OTProgressView {
    CGFloat _from;
    CGFloat _to;
    UIColor *_trackColor;
    UIColor *_barColor;
    BOOL _animate;
    CGFloat _shown;
    CALayer *_trackLayer;
    CALayer *_barLayer;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _from = 0;
        _to = 1;
        _trackColor = UIColor.grayColor;
        _barColor = UIColor.redColor;
        _trackLayer = [CALayer layer];
        _barLayer = [CALayer layer];
        [self.layer addSublayer:_trackLayer];
        [self.layer addSublayer:_barLayer];
    }
    return self;
}

- (void)bindFrom:(CGFloat)from to:(CGFloat)to animate:(BOOL)animate {
    _from = MIN(MAX(from, 0), 1);
    _to = MIN(MAX(to, 0), 1);
    _animate = animate;
    [self setNeedsLayout];
}

- (void)setFraction:(CGFloat)fraction {
    _animate = NO;
    [self bindFrom:0 to:fraction animate:NO];
    [self layoutIfNeeded];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat pad = 1;
    CGFloat full = MAX(self.bounds.size.height - pad * 2, 0);
    CGFloat displayScale = MAX(self.traitCollection.displayScale, 1);
    CGFloat slim = 6 * self.traitCollection.displayScale / displayScale;
    CGFloat thick = full > slim * 2.2 ? 6 : full;
    CGFloat top = MAX((self.bounds.size.height - thick) / 2, 0);
    _trackLayer.frame = CGRectMake(pad, top, MAX(self.bounds.size.width - pad * 2, 0), thick);
    _trackLayer.backgroundColor = _trackColor.CGColor;
    _trackLayer.cornerRadius = thick / 2;
    CGFloat inner = MAX(self.bounds.size.width - pad * 2, 0);
    CGFloat width = inner * MAX(_to - _from, 0);
    CGRect target = CGRectMake(pad + _from * inner, top, width, thick);
    _barLayer.backgroundColor = _barColor.CGColor;
    _barLayer.cornerRadius = thick / 2;
    if (_animate && _shown != width) {
        _barLayer.frame = CGRectMake(target.origin.x, top, _shown, thick);
        [UIView animateWithDuration:0.3 animations:^{
            self->_barLayer.frame = target;
        }];
    } else {
        _barLayer.frame = target;
    }
    _shown = width;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self seek:touches settled:NO];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self seek:touches settled:NO];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self seek:touches settled:YES];
}

- (void)seek:(NSSet<UITouch *> *)touches settled:(BOOL)settled {
    if (!self.seekable) {
        return;
    }
    UITouch *touch = touches.anyObject;
    if (!touch) {
        return;
    }
    CGFloat x = [touch locationInView:self].x;
    CGFloat pad = 1;
    CGFloat inner = MAX(self.bounds.size.width - pad * 2, 1);
    CGFloat fraction = MIN(MAX((x - pad) / inner, 0), 1);
    _animate = NO;
    [self bindFrom:0 to:fraction animate:NO];
    [self setNeedsLayout];
    [self layoutIfNeeded];
    if (self.onSeekChanged) {
        self.onSeekChanged(fraction, settled);
    }
}

- (void)setTrackColor:(UIColor *)color { _trackColor = color; }
- (void)setBarColor:(UIColor *)color { _barColor = color; }
- (UIColor *)trackColor { return _trackColor; }
- (UIColor *)barColor { return _barColor; }

@end

@interface OTLottieFallback : NSObject <OTLottiePlaying>
- (void)bindSrc:(NSString *)src repeatCount:(NSString *)repeatCount mode:(NSString *)mode autoPlay:(BOOL)autoPlay;
- (void)releaseAnimation;
@end

@implementation OTLottieFallback
- (void)bindSrc:(NSString *)src repeatCount:(NSString *)repeatCount mode:(NSString *)mode autoPlay:(BOOL)autoPlay {}
- (void)setPlaying:(BOOL)playing {}
- (void)releaseAnimation {}
@end

@implementation OTLottieView {
    id<OTLottiePlaying> _player;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _player = [OTLottieFallback new];
    }
    return self;
}

- (void)bindSrc:(NSString *)src repeatCount:(NSString *)repeatCount mode:(NSString *)mode autoPlay:(BOOL)autoPlay {
    if ([_player respondsToSelector:@selector(bindSrc:repeatCount:mode:autoPlay:)]) {
        [(id)_player bindSrc:src repeatCount:repeatCount mode:mode autoPlay:autoPlay];
    }
}

- (void)setPlaying:(BOOL)playing {
    [_player setPlaying:playing];
}

- (void)releaseAnimation {
    if ([_player respondsToSelector:@selector(releaseAnimation)]) {
        [(id)_player releaseAnimation];
    }
}

@end

@interface OTListCell : UICollectionViewCell
@end
@implementation OTListCell
@end

@implementation OTListView {
    UICollectionViewFlowLayout *_flow;
}

- (instancetype)init {
    UICollectionViewFlowLayout *flow = [UICollectionViewFlowLayout new];
    flow.minimumInteritemSpacing = 0;
    self = [super initWithFrame:CGRectZero collectionViewLayout:flow];
    if (self) {
        _flow = flow;
        self.backgroundColor = UIColor.clearColor;
        self.dataSource = self;
        self.delegate = self;
        [self registerClass:[OTListCell class] forCellWithReuseIdentifier:@"item"];
        _items = [JSONArray new];
    }
    return self;
}

- (void)applyDirection:(NSString *)direction gap:(CGFloat)gap {
    self.horizontal = [direction isEqualToString:TemplateKey.OT_HORIZONTAL];
    self.gap = gap;
    _flow.scrollDirection = self.horizontal ? UICollectionViewScrollDirectionHorizontal : UICollectionViewScrollDirectionVertical;
    _flow.minimumLineSpacing = gap;
}

- (void)setItems:(JSONArray *)array key:(NSString *)key {
    self.items = array ?: [JSONArray new];
    self.dataKey = key;
    [self reloadData];
}

- (NSInteger)itemCount {
    return self.items.size;
}

- (NSString *)itemFieldAtIndex:(NSInteger)index key:(NSString *)key {
    if (index < 0 || index >= self.items.size) {
        return @"";
    }
    JSONObject *item = [self.items getJSONObject:index];
    return [item getString:key] ?: @"";
}

- (void)updateItemAtIndex:(NSInteger)index fields:(NSDictionary<NSString *, NSString *> *)fields {
    if (index < 0 || index >= self.items.size) {
        return;
    }
    JSONObject *item = [self.items getJSONObject:index];
    if (!item) {
        return;
    }
    for (NSString *key in fields) {
        [OTData setValue:[JSONValue string:fields[key] ?: @""] forKey:key on:item];
    }
    [self reloadItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:index inSection:0]]];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.items.size;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    OTListCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"item" forIndexPath:indexPath];
    if (!self.itemTemplate || !self.template) {
        return cell;
    }
    JSONObject *data = [self.items getJSONObject:indexPath.item] ?: [JSONObject new];
    CGSize viewport = CGSizeZero;
    CGSize item = CGSizeZero;
    [self itemSize:data template:self.itemTemplate viewport:&viewport item:&item];
    for (UIView *child in cell.contentView.subviews) {
        [child removeFromSuperview];
    }
    NSError *error = nil;
    OTLaidOutNode *laid = [OTLayoutCall layoutRoot:self.itemTemplate data:data viewport:viewport windowWidth:self.windowWidth error:&error];
    UIView *view = laid ? [OTViewTree buildParsed:self.itemTemplate laid:laid template:self.template itemData:data error:&error] : nil;
    if (!view) {
        return cell;
    }
    view.frame = CGRectMake(0, 0, laid.frame.size.width, laid.frame.size.height);
    [cell.contentView addSubview:view];
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.itemTemplate) {
        return CGSizeMake(MAX(self.bounds.size.width, 1), 44);
    }
    CGSize viewport = CGSizeZero;
    CGSize item = CGSizeZero;
    [self itemSize:[self.items getJSONObject:indexPath.item] template:self.itemTemplate viewport:&viewport item:&item];
    return item;
}

- (void)itemSize:(JSONObject *)data template:(ParsedNode *)templateNode viewport:(CGSize *)viewport item:(CGSize *)item {
    CGFloat free = (CGFloat)NAN;
    CGSize measure = self.horizontal
        ? CGSizeMake(free, MAX(self.bounds.size.height, 1))
        : CGSizeMake(MAX(self.bounds.size.width, 1), free);
    if (viewport) {
        *viewport = measure;
    }
    OTLaidOutNode *laid = [OTLayoutCall layoutRoot:templateNode data:data viewport:measure windowWidth:self.windowWidth error:nil];
    CGSize size = laid ? CGSizeMake(MAX(laid.frame.size.width, 1), MAX(laid.frame.size.height, 1)) : CGSizeMake(MAX(self.bounds.size.width, 1), 44);
    if (item) {
        *item = size;
    }
}

- (NSDictionary *)firstScroll {
    NSArray<NSIndexPath *> *paths = [self.indexPathsForVisibleItems sortedArrayUsingSelector:@selector(compare:)];
    NSIndexPath *index = paths.firstObject;
    if (!index) {
        return nil;
    }
    UICollectionViewLayoutAttributes *attr = [self layoutAttributesForItemAtIndexPath:index];
    if (!attr) {
        return nil;
    }
    CGFloat delta = self.horizontal ? attr.frame.origin.x - self.contentOffset.x : attr.frame.origin.y - self.contentOffset.y;
    return @{@"index": @(index.item), @"offset": @(delta)};
}

- (void)restoreScrollIndex:(NSInteger)index offset:(CGFloat)offset {
    if (index < 0 || index >= self.items.size) {
        return;
    }
    [self layoutIfNeeded];
    NSIndexPath *path = [NSIndexPath indexPathForItem:index inSection:0];
    UICollectionViewLayoutAttributes *attr = [self layoutAttributesForItemAtIndexPath:path];
    if (!attr) {
        return;
    }
    if (self.horizontal) {
        self.contentOffset = CGPointMake(attr.frame.origin.x - offset, self.contentOffset.y);
    } else {
        self.contentOffset = CGPointMake(self.contentOffset.x, attr.frame.origin.y - offset);
    }
}

@end

@interface OTImeDismiss : NSObject <UIGestureRecognizerDelegate>
@property (class, nonatomic, readonly) OTImeDismiss *shared;
- (void)dismiss:(UITapGestureRecognizer *)gesture;
@end

@implementation OTIme

+ (void)dismiss:(UIView *)view {
    [view endEditing:YES];
}

+ (void)installOn:(UIView *)view {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:OTImeDismiss.shared action:@selector(dismiss:)];
    tap.cancelsTouchesInView = NO;
    tap.delegate = OTImeDismiss.shared;
    [view addGestureRecognizer:tap];
}

@end

@implementation OTImeDismiss

+ (OTImeDismiss *)shared {
    static OTImeDismiss *target;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ target = [OTImeDismiss new]; });
    return target;
}

- (void)dismiss:(UITapGestureRecognizer *)gesture {
    UIView *root = gesture.view;
    if (!root) {
        return;
    }
    CGPoint point = [gesture locationInView:root];
    if ([self hitInput:root point:point]) {
        return;
    }
    [root endEditing:YES];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    UIView *view = touch.view;
    while (view) {
        if ([view isKindOfClass:[UITextField class]] || [view isKindOfClass:[UITextView class]]) {
            return NO;
        }
        view = view.superview;
    }
    return YES;
}

- (BOOL)hitInput:(UIView *)view point:(CGPoint)point {
    CGPoint local = [view convertPoint:point fromView:view.superview ?: view];
    if (([view isKindOfClass:[UITextField class]] || [view isKindOfClass:[UITextView class]]) && CGRectContainsPoint(view.bounds, local)) {
        return YES;
    }
    for (UIView *child in view.subviews) {
        if ([self hitInput:child point:point]) {
            return YES;
        }
    }
    return NO;
}

@end

@implementation OTToast

+ (void)show:(NSString *)message inView:(UIView *)view {
    UIView *host = view.window ?: view;
    if (!host) {
        return;
    }
    UILabel *label = [UILabel new];
    label.text = message;
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont systemFontOfSize:14];
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.92];
    label.layer.cornerRadius = 8;
    label.clipsToBounds = YES;
    CGFloat maxWidth = MIN(MAX(host.bounds.size.width - 48, 0), 280);
    CGSize textSize = [label sizeThatFits:CGSizeMake(MAX(maxWidth - 32, 0), CGFLOAT_MAX)];
    CGFloat width = MIN(maxWidth, ceil(textSize.width) + 32);
    CGFloat height = ceil(textSize.height) + 20;
    CGFloat bottom = host.safeAreaInsets.bottom + 24;
    label.frame = CGRectMake((host.bounds.size.width - width) / 2, MAX(host.bounds.size.height - bottom - height, 0), width, height);
    [host addSubview:label];
    [UIView animateWithDuration:0.25 delay:2.0 options:0 animations:^{
        label.alpha = 0;
    } completion:^(BOOL finished) {
        [label removeFromSuperview];
    }];
}

@end

@implementation UIView (OtterController)

- (UIViewController *)ot_controller {
    UIResponder *responder = self;
    while (responder) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
        responder = responder.nextResponder;
    }
    return nil;
}

@end
