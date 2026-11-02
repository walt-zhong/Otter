#import "OTStyle.h"
#import "../Engine/OTBridge.h"
#import "OTNodes.h"
#import <objc/runtime.h>

@implementation OTChrome

+ (CGFloat)scaleForView:(UIView *)view {
    return [OTViewMark bind:view].scale;
}

+ (NSString *)eval:(NSString *)raw data:(JSONObject *)data {
    if (!raw) {
        return nil;
    }
    if ([raw containsString:@"$"] || [raw containsString:@"size("] || [raw containsString:@"env("]) {
        id result = [[ExpressionEngine shared] resultWithExpression:raw data:[OTData foundation:data]];
        return [OTData display:result];
    }
    return raw;
}

+ (void)applyView:(UIView *)view
           fields:(NSDictionary<NSString *, NSString *> *)fields
            scale:(CGFloat)scale
         itemData:(JSONObject *)itemData {
    NSString *background = [self eval:fields[TemplateKey.ATTR_BACKGROUND] data:itemData];
    NSString *glassStyle = fields[TemplateKey.ATTR_GLASS_STYLE];
    if (glassStyle) {
        [OTGlassLayer attach:view fields:fields itemData:itemData];
    } else {
        [OTGlassLayer remove:view];
        [self applyBackground:view raw:background scale:scale];
    }
    [self applyCorner:view fields:fields scale:scale];
}

+ (void)applyBackground:(UIView *)view raw:(NSString *)raw scale:(CGFloat)scale {
    (void)scale;
    NSMutableArray<CALayer *> *drop = [NSMutableArray array];
    for (CALayer *layer in view.layer.sublayers) {
        if ([layer.name isEqualToString:@"otter.gradient"]) {
            [drop addObject:layer];
        }
    }
    for (CALayer *layer in drop) {
        [layer removeFromSuperlayer];
    }
    if ([raw hasPrefix:@"linear-gradient"]) {
        CAGradientLayer *layer = [CAGradientLayer layer];
        layer.name = @"otter.gradient";
        layer.frame = view.bounds;
        NSDictionary *parsed = [self parseGradient:raw];
        NSMutableArray *colors = [NSMutableArray array];
        for (UIColor *color in parsed[@"colors"]) {
            [colors addObject:(id)color.CGColor];
        }
        layer.colors = colors;
        layer.startPoint = [parsed[@"start"] CGPointValue];
        layer.endPoint = [parsed[@"end"] CGPointValue];
        [view.layer insertSublayer:layer atIndex:0];
        view.backgroundColor = UIColor.clearColor;
        return;
    }
    if ([raw hasPrefix:@"res:"]) {
        NSString *name = [raw substringFromIndex:4];
        if ([view isKindOfClass:[OTColumnView class]]) {
            [(OTColumnView *)view showBackdropNamed:name];
        } else {
            UIImage *image = [OTAssets imageNamed:name];
            view.layer.contents = image ? (__bridge id)image.CGImage : nil;
            view.layer.contentsGravity = kCAGravityResizeAspectFill;
        }
        return;
    }
    view.layer.contents = nil;
    if ([view isKindOfClass:[OTColumnView class]]) {
        [(OTColumnView *)view clearBackdrop];
    }
    if (raw) {
        UIColor *color = [OTColorParser color:raw];
        if (color) {
            view.backgroundColor = color;
        }
    } else {
        view.backgroundColor = UIColor.clearColor;
    }
}

+ (NSDictionary *)parseGradient:(NSString *)raw {
    NSString *body = [raw substringFromIndex:@"linear-gradient(".length];
    if ([body hasSuffix:@")"]) {
        body = [body substringToIndex:body.length - 1];
    }
    NSRange comma = [body rangeOfString:@","];
    NSString *direction = @"to bottom";
    NSString *colorText = @"";
    if (comma.location != NSNotFound) {
        direction = [[body substringToIndex:comma.location] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        colorText = [body substringFromIndex:NSMaxRange(comma)];
    }
    NSMutableArray<UIColor *> *colors = [NSMutableArray array];
    for (NSString *part in [colorText componentsSeparatedByString:@","]) {
        UIColor *color = [OTColorParser color:[part stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]];
        if (color) {
            [colors addObject:color];
        }
    }
    if (colors.count == 0) {
        [colors addObject:UIColor.clearColor];
        [colors addObject:UIColor.clearColor];
    }
    CGPoint start = CGPointMake(0.5, 0);
    CGPoint end = CGPointMake(0.5, 1);
    if ([direction isEqualToString:@"to top"]) {
        start = CGPointMake(0.5, 1); end = CGPointMake(0.5, 0);
    } else if ([direction isEqualToString:@"to left"]) {
        start = CGPointMake(1, 0.5); end = CGPointMake(0, 0.5);
    } else if ([direction isEqualToString:@"to right"]) {
        start = CGPointMake(0, 0.5); end = CGPointMake(1, 0.5);
    } else if ([direction isEqualToString:@"to top left"]) {
        start = CGPointMake(1, 1); end = CGPointMake(0, 0);
    } else if ([direction isEqualToString:@"to top right"]) {
        start = CGPointMake(0, 1); end = CGPointMake(1, 0);
    } else if ([direction isEqualToString:@"to bottom left"]) {
        start = CGPointMake(1, 0); end = CGPointMake(0, 1);
    } else if ([direction isEqualToString:@"to bottom right"]) {
        start = CGPointMake(0, 0); end = CGPointMake(1, 1);
    }
    return @{@"colors": colors, @"start": [NSValue valueWithCGPoint:start], @"end": [NSValue valueWithCGPoint:end]};
}

+ (void)applyCorner:(UIView *)view fields:(NSDictionary<NSString *, NSString *> *)fields scale:(CGFloat)scale {
    CGFloat (^points)(NSString *) = ^CGFloat(NSString *key) {
        NSNumber *value = [OTMeasure points:fields[key] scale:scale];
        return value ? value.doubleValue : -1;
    };
    CGFloat uniform = points(TemplateKey.ATTR_RADIUS);
    if (uniform < 0) uniform = 0;
    CGFloat topLeft = points(TemplateKey.ATTR_LEFT_TOP_RADIUS);
    CGFloat topRight = points(TemplateKey.ATTR_RIGHT_TOP_RADIUS);
    CGFloat bottomRight = points(TemplateKey.ATTR_RIGHT_BOTTOM_RADIUS);
    CGFloat bottomLeft = points(TemplateKey.ATTR_LEFT_BOTTOM_RADIUS);
    if (topLeft < 0) topLeft = uniform;
    if (topRight < 0) topRight = uniform;
    if (bottomRight < 0) bottomRight = uniform;
    if (bottomLeft < 0) bottomLeft = uniform;
    NSArray<NSNumber *> *corners = @[@(topLeft), @(topRight), @(bottomRight), @(bottomLeft)];
    NSNumber *border = [OTMeasure points:fields[TemplateKey.ATTR_BORDER_WIDTH] scale:scale];
    CGFloat borderWidth = border ? border.doubleValue : 0;
    UIColor *borderColor = [OTColorParser color:fields[TemplateKey.ATTR_BORDER_COLOR]];
    BOOL same = YES;
    for (NSNumber *corner in corners) {
        if (fabs(corner.doubleValue - corners[0].doubleValue) >= 0.5) {
            same = NO;
            break;
        }
    }
    BOOL any = NO;
    for (NSNumber *corner in corners) {
        if (corner.doubleValue > 0) any = YES;
    }
    if (same && corners[0].doubleValue > 0) {
        view.layer.cornerRadius = corners[0].doubleValue;
        view.layer.mask = nil;
        view.clipsToBounds = YES;
    } else if (any) {
        CAShapeLayer *mask = [CAShapeLayer layer];
        mask.path = [self cornerPath:view.bounds radii:corners].CGPath;
        view.layer.mask = mask;
        view.clipsToBounds = YES;
    } else {
        view.layer.cornerRadius = 0;
        view.layer.mask = nil;
    }
    if (borderWidth > 0 && borderColor) {
        view.layer.borderWidth = borderWidth;
        view.layer.borderColor = borderColor.CGColor;
    } else if (view.layer.borderWidth > 0 && fields[TemplateKey.ATTR_BORDER_WIDTH] == nil) {
        view.layer.borderWidth = 0;
    }
    [OTViewMark bind:view].radii = corners;
}

+ (UIBezierPath *)cornerPath:(CGRect)rect radii:(NSArray<NSNumber *> *)radii {
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat tl = radii.count > 0 ? radii[0].doubleValue : 0;
    CGFloat tr = radii.count > 1 ? radii[1].doubleValue : 0;
    CGFloat br = radii.count > 2 ? radii[2].doubleValue : 0;
    CGFloat bl = radii.count > 3 ? radii[3].doubleValue : 0;
    [path moveToPoint:CGPointMake(CGRectGetMinX(rect) + tl, CGRectGetMinY(rect))];
    [path addLineToPoint:CGPointMake(CGRectGetMaxX(rect) - tr, CGRectGetMinY(rect))];
    [path addArcWithCenter:CGPointMake(CGRectGetMaxX(rect) - tr, CGRectGetMinY(rect) + tr) radius:tr startAngle:-M_PI_2 endAngle:0 clockwise:YES];
    [path addLineToPoint:CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect) - br)];
    [path addArcWithCenter:CGPointMake(CGRectGetMaxX(rect) - br, CGRectGetMaxY(rect) - br) radius:br startAngle:0 endAngle:M_PI_2 clockwise:YES];
    [path addLineToPoint:CGPointMake(CGRectGetMinX(rect) + bl, CGRectGetMaxY(rect))];
    [path addArcWithCenter:CGPointMake(CGRectGetMinX(rect) + bl, CGRectGetMaxY(rect) - bl) radius:bl startAngle:M_PI_2 endAngle:M_PI clockwise:YES];
    [path addLineToPoint:CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect) + tl)];
    [path addArcWithCenter:CGPointMake(CGRectGetMinX(rect) + tl, CGRectGetMinY(rect) + tl) radius:tl startAngle:M_PI endAngle:-M_PI_2 clockwise:YES];
    [path closePath];
    return path;
}

@end

static char OTGlassKey;

@implementation OTGlassLayer

+ (void)attach:(UIView *)view fields:(NSDictionary<NSString *, NSString *> *)fields itemData:(JSONObject *)itemData {
    UIVisualEffectView *effectView = objc_getAssociatedObject(view, &OTGlassKey);
    if (!effectView) {
        effectView = [[UIVisualEffectView alloc] init];
        effectView.userInteractionEnabled = NO;
        effectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        objc_setAssociatedObject(view, &OTGlassKey, effectView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [view insertSubview:effectView atIndex:0];
    }
    effectView.frame = view.bounds;
    NSString *style = fields[TemplateKey.ATTR_GLASS_STYLE] ?: @"regular";
    UIColor *tint = [OTColorParser color:[OTChrome eval:fields[TemplateKey.ATTR_GLASS_TINT] data:itemData]];
    BOOL interactive = [fields[TemplateKey.ATTR_GLASS_INTERACTIVE] isEqualToString:@"true"];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        UIGlassEffect *glass = [UIGlassEffect effectWithStyle:[style isEqualToString:@"clear"] ? UIGlassEffectStyleClear : UIGlassEffectStyleRegular];
        glass.tintColor = tint;
        glass.interactive = interactive;
        effectView.effect = glass;
    } else
#endif
    {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:[style isEqualToString:@"clear"] ? UIBlurEffectStyleSystemUltraThinMaterial : UIBlurEffectStyleSystemThinMaterial];
        effectView.effect = blur;
        UIView *overlay = [effectView.contentView viewWithTag:71];
        if (!overlay) {
            overlay = [UIView new];
            overlay.tag = 71;
            overlay.userInteractionEnabled = NO;
            [effectView.contentView addSubview:overlay];
        }
        overlay.frame = effectView.bounds;
        overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        if (tint) {
            overlay.backgroundColor = tint;
        } else if ([style isEqualToString:@"clear"]) {
            overlay.backgroundColor = [UIColor colorWithWhite:1 alpha:0.04];
        } else {
            overlay.backgroundColor = [UIColor colorWithWhite:1 alpha:0.18];
        }
    }
    effectView.layer.cornerRadius = view.layer.cornerRadius;
    effectView.clipsToBounds = YES;
    [OTViewMark bind:view].glassInteractive = interactive;
}

+ (void)remove:(UIView *)view {
    UIView *effect = objc_getAssociatedObject(view, &OTGlassKey);
    [effect removeFromSuperview];
    objc_setAssociatedObject(view, &OTGlassKey, nil, OBJC_ASSOCIATION_ASSIGN);
}

+ (void)layout:(UIView *)view {
    UIVisualEffectView *effect = objc_getAssociatedObject(view, &OTGlassKey);
    if (![effect isKindOfClass:[UIVisualEffectView class]]) {
        return;
    }
    effect.frame = view.bounds;
    effect.layer.cornerRadius = view.layer.cornerRadius;
    CAShapeLayer *mask = (CAShapeLayer *)view.layer.mask;
    if ([mask isKindOfClass:[CAShapeLayer class]] && mask.path) {
        CAShapeLayer *copy = [CAShapeLayer layer];
        copy.path = mask.path;
        effect.layer.mask = copy;
    }
}

@end
