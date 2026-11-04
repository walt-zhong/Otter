#import "OTStyle.h"
#import "../Engine/OTBridge.h"

@interface OTPathData : NSObject
+ (UIBezierPath *)bezier:(NSString *)data;
@end

@implementation OTVectorImage

+ (NSNumber *)attr:(NSString *)text name:(NSString *)name {
    NSString *token = [NSString stringWithFormat:@"%@=\"", name];
    NSRange range = [text rangeOfString:token];
    if (range.location == NSNotFound) {
        return nil;
    }
    NSString *rest = [text substringFromIndex:NSMaxRange(range)];
    NSRange end = [rest rangeOfString:@"\""];
    if (end.location == NSNotFound) {
        return nil;
    }
    NSString *raw = [rest substringToIndex:end.location];
    raw = [raw stringByReplacingOccurrencesOfString:@"dp" withString:@""];
    raw = [raw stringByReplacingOccurrencesOfString:@"px" withString:@""];
    return @(raw.doubleValue);
}

+ (NSString *)stringAttr:(NSString *)text name:(NSString *)name {
    NSString *token = [NSString stringWithFormat:@"%@=\"", name];
    NSRange range = [text rangeOfString:token];
    if (range.location == NSNotFound) {
        return nil;
    }
    NSString *rest = [text substringFromIndex:NSMaxRange(range)];
    NSRange end = [rest rangeOfString:@"\""];
    if (end.location == NSNotFound) {
        return nil;
    }
    return [rest substringToIndex:end.location];
}

+ (UIImage *)imageAtURL:(NSURL *)url {
    NSData *data = [NSData dataWithContentsOfURL:url];
    NSString *text = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
    if (text.length == 0 || ![text containsString:@"<vector"]) {
        return nil;
    }
    CGFloat viewportW = [self attr:text name:@"viewportWidth"].doubleValue ?: 24;
    CGFloat viewportH = [self attr:text name:@"viewportHeight"].doubleValue ?: 24;
    CGFloat width = [self attr:text name:@"android:width"].doubleValue ?: viewportW;
    CGFloat height = [self attr:text name:@"android:height"].doubleValue ?: viewportH;
    CGSize size = CGSizeMake(MAX(width, 1), MAX(height, 1));
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGContextScaleCTM(context.CGContext, size.width / MAX(viewportW, 1), size.height / MAX(viewportH, 1));
        NSArray<NSString *> *parts = [text componentsSeparatedByString:@"<path"];
        for (NSUInteger index = 1; index < parts.count; index++) {
            NSString *body = [parts[index] componentsSeparatedByString:@"/>"].firstObject ?: parts[index];
            NSString *pathData = [self stringAttr:body name:@"android:pathData"] ?: [self stringAttr:body name:@"pathData"] ?: @"";
            NSString *fill = [self stringAttr:body name:@"android:fillColor"] ?: [self stringAttr:body name:@"fillColor"];
            NSString *stroke = [self stringAttr:body name:@"android:strokeColor"] ?: [self stringAttr:body name:@"strokeColor"];
            CGFloat strokeWidth = [self attr:body name:@"android:strokeWidth"].doubleValue;
            if (strokeWidth == 0) {
                strokeWidth = [self attr:body name:@"strokeWidth"].doubleValue;
            }
            BOOL roundCap = [[self stringAttr:body name:@"android:strokeLineCap"] ?: [self stringAttr:body name:@"strokeLineCap"] isEqualToString:@"round"];
            BOOL roundJoin = [[self stringAttr:body name:@"android:strokeLineJoin"] ?: [self stringAttr:body name:@"strokeLineJoin"] isEqualToString:@"round"];
            UIBezierPath *bezier = [OTPathData bezier:pathData];
            if (fill.length > 0 && ![fill isEqualToString:@"#00000000"]) {
                [[OTColorParser color:fill] setFill];
                [bezier fill];
            }
            if (stroke.length > 0 && strokeWidth > 0) {
                [[OTColorParser color:stroke] setStroke];
                bezier.lineWidth = strokeWidth;
                bezier.lineCapStyle = roundCap ? kCGLineCapRound : kCGLineCapButt;
                bezier.lineJoinStyle = roundJoin ? kCGLineJoinRound : kCGLineJoinMiter;
                [bezier stroke];
            }
        }
    }];
}

@end

@implementation OTPathData

+ (NSArray<NSString *> *)tokenize:(NSString *)data {
    NSMutableArray<NSString *> *tokens = [NSMutableArray array];
    NSMutableString *current = [NSMutableString string];
    void (^flush)(void) = ^{
        if (current.length > 0) {
            [tokens addObject:[current copy]];
            [current setString:@""];
        }
    };
    for (NSUInteger i = 0; i < data.length; i++) {
        unichar character = [data characterAtIndex:i];
        BOOL letter = [[NSCharacterSet letterCharacterSet] characterIsMember:character];
        BOOL space = [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:character];
        if (letter || character == ',' || space) {
            flush();
            if (letter) {
                [tokens addObject:[NSString stringWithCharacters:&character length:1]];
            }
        } else if (character == '-' && current.length > 0 && ![current hasSuffix:@"e"] && ![current hasSuffix:@"E"]) {
            flush();
            [current appendFormat:@"%C", character];
        } else {
            [current appendFormat:@"%C", character];
        }
    }
    flush();
    return tokens;
}

+ (BOOL)read:(NSArray<NSString *> *)tokens index:(NSInteger *)index into:(CGFloat *)out {
    if (*index >= (NSInteger)tokens.count) {
        return NO;
    }
    NSScanner *scanner = [NSScanner scannerWithString:tokens[*index]];
    double value = 0;
    if (![scanner scanDouble:&value] || !scanner.isAtEnd) {
        return NO;
    }
    *index += 1;
    *out = (CGFloat)value;
    return YES;
}

+ (UIBezierPath *)bezier:(NSString *)data {
    UIBezierPath *path = [UIBezierPath bezierPath];
    NSArray<NSString *> *tokens = [self tokenize:data];
    NSInteger index = 0;
    unichar command = 'M';
    CGPoint current = CGPointZero;
    CGPoint start = CGPointZero;
    while (index < (NSInteger)tokens.count) {
        NSString *token = tokens[index];
        if (token.length == 1) {
            unichar first = [token characterAtIndex:0];
            if ([[NSCharacterSet letterCharacterSet] characterIsMember:first]) {
                command = first;
                index += 1;
            }
        }
        BOOL relative = command >= 'a' && command <= 'z';
        unichar absolute = (unichar)toupper(command);
        CGFloat x = 0, y = 0, x1 = 0, y1 = 0, x2 = 0, y2 = 0;
        if (absolute == 'M') {
            if (![self read:tokens index:&index into:&x] || ![self read:tokens index:&index into:&y]) return path;
            current = relative ? CGPointMake(current.x + x, current.y + y) : CGPointMake(x, y);
            [path moveToPoint:current];
            start = current;
            command = relative ? 'l' : 'L';
        } else if (absolute == 'L') {
            if (![self read:tokens index:&index into:&x] || ![self read:tokens index:&index into:&y]) return path;
            current = relative ? CGPointMake(current.x + x, current.y + y) : CGPointMake(x, y);
            [path addLineToPoint:current];
        } else if (absolute == 'H') {
            if (![self read:tokens index:&index into:&x]) return path;
            current.x = relative ? current.x + x : x;
            [path addLineToPoint:current];
        } else if (absolute == 'V') {
            if (![self read:tokens index:&index into:&y]) return path;
            current.y = relative ? current.y + y : y;
            [path addLineToPoint:current];
        } else if (absolute == 'C') {
            if (![self read:tokens index:&index into:&x1] || ![self read:tokens index:&index into:&y1] ||
                ![self read:tokens index:&index into:&x2] || ![self read:tokens index:&index into:&y2] ||
                ![self read:tokens index:&index into:&x] || ![self read:tokens index:&index into:&y]) return path;
            CGPoint c1 = relative ? CGPointMake(current.x + x1, current.y + y1) : CGPointMake(x1, y1);
            CGPoint c2 = relative ? CGPointMake(current.x + x2, current.y + y2) : CGPointMake(x2, y2);
            current = relative ? CGPointMake(current.x + x, current.y + y) : CGPointMake(x, y);
            [path addCurveToPoint:current controlPoint1:c1 controlPoint2:c2];
        } else if (absolute == 'Z') {
            [path closePath];
            current = start;
        } else if (absolute == 'A') {
            CGFloat rx = 0, ry = 0, rotation = 0, large = 0, sweep = 0;
            if (![self read:tokens index:&index into:&rx] || ![self read:tokens index:&index into:&ry] ||
                ![self read:tokens index:&index into:&rotation] || ![self read:tokens index:&index into:&large] ||
                ![self read:tokens index:&index into:&sweep] || ![self read:tokens index:&index into:&x] ||
                ![self read:tokens index:&index into:&y]) return path;
            (void)rotation;
            CGPoint end = relative ? CGPointMake(current.x + x, current.y + y) : CGPointMake(x, y);
            [self addArc:path from:current to:end rx:rx ry:ry large:large != 0 sweep:sweep != 0];
            current = end;
        } else {
            index += 1;
        }
    }
    return path;
}

+ (void)addArc:(UIBezierPath *)path from:(CGPoint)from to:(CGPoint)to rx:(CGFloat)rx ry:(CGFloat)ry large:(BOOL)large sweep:(BOOL)sweep {
    if (rx == 0 || ry == 0) {
        [path addLineToPoint:to];
        return;
    }
    CGFloat radius = MAX(rx, ry);
    CGPoint center = CGPointMake((from.x + to.x) / 2, (from.y + to.y) / 2);
    CGPoint control = CGPointMake(center.x + (sweep ? radius : -radius) * 0.15, center.y + (large ? -radius : radius) * 0.15);
    [path addQuadCurveToPoint:to controlPoint:control];
    if (fabs(from.x - to.x) < 0.01 && fabs(from.y - to.y) < 0.01) {
        [path addArcWithCenter:center radius:radius startAngle:0 endAngle:M_PI * 2 clockwise:YES];
    }
}

@end
