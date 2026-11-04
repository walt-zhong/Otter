#import "OTBridge.h"
#import "../Render/OTStyle.h"

NSError *OTParseError(NSString *message) {
    return [NSError errorWithDomain:@"TemplateParseException"
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @""}];
}

static BOOL OTIsBoolean(NSNumber *number) {
    return CFGetTypeID((__bridge CFTypeRef)number) == CFBooleanGetTypeID();
}

@implementation OTAssets

static NSBundle *OTAssetBundle;

+ (NSBundle *)bundle {
    return OTAssetBundle ?: NSBundle.mainBundle;
}

+ (void)setBundle:(NSBundle *)bundle {
    OTAssetBundle = bundle;
}

+ (NSArray<NSURL *> *)roots {
    NSMutableArray<NSURL *> *roots = [NSMutableArray array];
    NSURL *bundleURL = self.bundle.bundleURL;
    [roots addObject:bundleURL];
    [roots addObject:[bundleURL URLByAppendingPathComponent:@"assets"]];
    [roots addObject:[bundleURL URLByAppendingPathComponent:@"images"]];
    [roots addObject:[bundleURL URLByAppendingPathComponent:@"res"]];
    NSFileManager *manager = NSFileManager.defaultManager;
    NSArray<NSString *> *seeds = @[bundleURL.path ?: @"", manager.currentDirectoryPath ?: @""];
    for (NSString *seed in seeds) {
        if (seed.length == 0) {
            continue;
        }
        NSString *cursor = seed;
        for (NSInteger hop = 0; hop < 8; hop++) {
            NSString *marker = [cursor stringByAppendingPathComponent:@"OtterDemo.xcodeproj"];
            BOOL isDirectory = NO;
            if ([manager fileExistsAtPath:marker isDirectory:&isDirectory] && isDirectory) {
                [roots addObject:[NSURL fileURLWithPath:[cursor stringByAppendingPathComponent:@"Demo/assets"] isDirectory:YES]];
                [roots addObject:[NSURL fileURLWithPath:[cursor stringByAppendingPathComponent:@"Demo/images"] isDirectory:YES]];
                break;
            }
            NSString *parent = cursor.stringByDeletingLastPathComponent;
            if (parent.length == 0 || [parent isEqualToString:cursor]) {
                break;
            }
            cursor = parent;
        }
    }
    return roots;
}

+ (BOOL)pathIsContained:(NSString *)path {
    if (path.length == 0 || [path hasPrefix:@"/"] || [path hasPrefix:@"\\"]) {
        return NO;
    }
    if ([path rangeOfString:@"\\"].location != NSNotFound || [path rangeOfString:@"\0"].location != NSNotFound) {
        return NO;
    }
    for (NSString *part in [path componentsSeparatedByString:@"/"]) {
        if ([part isEqualToString:@".."] || [part isEqualToString:@"."]) {
            return NO;
        }
    }
    return YES;
}

+ (BOOL)candidate:(NSURL *)candidate staysInside:(NSURL *)root {
    NSString *rootPath = root.URLByStandardizingPath.path;
    NSString *candidatePath = candidate.URLByStandardizingPath.path;
    if (rootPath.length == 0 || candidatePath.length == 0) {
        return NO;
    }
    if ([candidatePath isEqualToString:rootPath]) {
        return YES;
    }
    NSString *prefix = [rootPath hasSuffix:@"/"] ? rootPath : [rootPath stringByAppendingString:@"/"];
    return [candidatePath hasPrefix:prefix];
}

+ (NSURL *)file:(NSString *)path {
    if (![self pathIsContained:path]) {
        return nil;
    }
    NSFileManager *manager = NSFileManager.defaultManager;
    for (NSURL *root in self.roots) {
        NSURL *candidate = [root URLByAppendingPathComponent:path];
        if (![self candidate:candidate staysInside:root]) {
            continue;
        }
        if ([manager fileExistsAtPath:candidate.path]) {
            return candidate;
        }
    }
    return nil;
}

+ (NSString *)text:(NSString *)path error:(NSError **)error {
    NSURL *url = [self file:path];
    if (!url) {
        if (error) {
            *error = OTParseError([NSString stringWithFormat:@"找不到模版 %@", path]);
        }
        return nil;
    }
    NSError *readError = nil;
    NSString *text = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&readError];
    if (!text && error) {
        *error = readError ?: OTParseError([NSString stringWithFormat:@"找不到模版 %@", path]);
    }
    return text;
}

+ (UIImage *)imageNamed:(NSString *)name {
    if (![self pathIsContained:name] || [name containsString:@"/"]) {
        return nil;
    }
    NSArray<NSString *> *folders = @[@"drawable-nodpi", @"drawable", @"drawable-hdpi", @"drawable-xhdpi", @"drawable-xxhdpi", @"drawable-xxxhdpi", @"mipmap-xxhdpi", @"mipmap"];
    NSArray<NSString *> *extensions = @[@"png", @"jpg", @"jpeg", @"webp"];
    NSFileManager *manager = NSFileManager.defaultManager;
    for (NSURL *root in self.roots) {
        for (NSString *folder in folders) {
            for (NSString *ext in extensions) {
                NSURL *url = [[root URLByAppendingPathComponent:folder] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", name, ext]];
                if ([manager fileExistsAtPath:url.path]) {
                    UIImage *image = [UIImage imageWithContentsOfFile:url.path];
                    if (image) {
                        return image;
                    }
                }
            }
            NSURL *xml = [[root URLByAppendingPathComponent:folder] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.xml", name]];
            if ([manager fileExistsAtPath:xml.path]) {
                UIImage *image = [OTVectorImage imageAtURL:xml];
                if (image) {
                    return image;
                }
            }
        }
    }
    return [UIImage imageNamed:name];
}

@end

@implementation OTMeasure

+ (NSNumber *)points:(NSString *)raw scale:(CGFloat)scale {
    NSString *text = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (text.length == 0) {
        return nil;
    }
    if ([text hasSuffix:@"px"] || [text hasSuffix:@"pt"]) {
        text = [text substringToIndex:text.length - 2];
    }
    if ([text hasSuffix:@"%"]) {
        return nil;
    }
    double number = 0;
    NSScanner *scanner = [NSScanner scannerWithString:text];
    if (![scanner scanDouble:&number] || !scanner.isAtEnd) {
        return nil;
    }
    return @(number * scale);
}

@end

@implementation OTColorParser

+ (UIColor *)color:(NSString *)raw {
    NSString *text = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (text.length == 0) {
        return nil;
    }
    if ([text containsString:@"%"]) {
        NSArray<NSString *> *parts = [text componentsSeparatedByString:@" "];
        if (parts.count == 2) {
            text = parts[0];
        }
    }
    if ([text.lowercaseString isEqualToString:@"transparent"]) {
        return UIColor.clearColor;
    }
    if ([text hasPrefix:@"#"]) {
        NSString *hex = [text substringFromIndex:1];
        if (hex.length == 3) {
            NSMutableString *expanded = [NSMutableString string];
            for (NSUInteger i = 0; i < hex.length; i++) {
                unichar c = [hex characterAtIndex:i];
                [expanded appendFormat:@"%C%C", c, c];
            }
            hex = expanded;
        }
        unsigned long long value = 0;
        NSScanner *scanner = [NSScanner scannerWithString:hex];
        if (![scanner scanHexLongLong:&value]) {
            return nil;
        }
        if (hex.length == 6) {
            return [UIColor colorWithRed:((value >> 16) & 0xff) / 255.0
                                    green:((value >> 8) & 0xff) / 255.0
                                     blue:(value & 0xff) / 255.0
                                    alpha:1];
        }
        if (hex.length == 8) {
            return [UIColor colorWithRed:((value >> 16) & 0xff) / 255.0
                                    green:((value >> 8) & 0xff) / 255.0
                                     blue:(value & 0xff) / 255.0
                                    alpha:((value >> 24) & 0xff) / 255.0];
        }
        return nil;
    }
    if ([text.lowercaseString hasPrefix:@"rgb"]) {
        NSRange open = [text rangeOfString:@"("];
        NSRange close = [text rangeOfString:@")" options:NSBackwardsSearch];
        if (open.location != NSNotFound && close.location != NSNotFound && close.location > open.location) {
            NSString *body = [text substringWithRange:NSMakeRange(open.location + 1, close.location - open.location - 1)];
            NSArray<NSString *> *parts = [body componentsSeparatedByString:@","];
            if (parts.count >= 3) {
                double r = parts[0].doubleValue;
                double g = parts[1].doubleValue;
                double b = parts[2].doubleValue;
                CGFloat a = parts.count > 3 ? (CGFloat)parts[3].doubleValue : 1;
                return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a];
            }
        }
    }
    NSString *named = text.lowercaseString;
    if ([named isEqualToString:@"black"]) return UIColor.blackColor;
    if ([named isEqualToString:@"dkgray"]) return [UIColor colorWithWhite:0.333 alpha:1];
    if ([named isEqualToString:@"gray"]) return UIColor.grayColor;
    if ([named isEqualToString:@"ltgray"]) return [UIColor colorWithWhite:0.667 alpha:1];
    if ([named isEqualToString:@"white"]) return UIColor.whiteColor;
    if ([named isEqualToString:@"red"]) return UIColor.redColor;
    if ([named isEqualToString:@"green"]) return [UIColor colorWithRed:0 green:0.5 blue:0 alpha:1];
    if ([named isEqualToString:@"blue"]) return UIColor.blueColor;
    if ([named isEqualToString:@"yellow"]) return UIColor.yellowColor;
    if ([named isEqualToString:@"cyan"]) return UIColor.cyanColor;
    if ([named isEqualToString:@"magenta"]) return UIColor.magentaColor;
    return nil;
}

@end

@implementation OTFont

+ (UIFont *)fontForFields:(NSDictionary<NSString *, NSString *> *)fields scale:(CGFloat)scale {
    NSString *raw = fields[TemplateKey.ATTR_TEXT_SIZE] ?: @"12px";
    raw = [raw stringByReplacingOccurrencesOfString:@"px" withString:@""];
    raw = [raw stringByReplacingOccurrencesOfString:@"pt" withString:@""];
    raw = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    double parsedSize = 12;
    NSScanner *sizeScanner = [NSScanner scannerWithString:raw];
    if (![sizeScanner scanDouble:&parsedSize] || !sizeScanner.isAtEnd) {
        parsedSize = 12;
    }
    // Same Java round as OTSize. Drawing the raw scaled size makes the glyphs
    // a fraction wider than the box the layout measured, and UILabel wraps the tail.
    CGFloat size = floor((CGFloat)parsedSize * scale + 0.5);
    UIFontWeight weight = UIFontWeightRegular;
    NSString *named = fields[TemplateKey.ATTR_FONT_WEIGHT];
    if ([named isEqualToString:@"bold"]) {
        weight = UIFontWeightBold;
    } else if ([named isEqualToString:@"medium"]) {
        weight = UIFontWeightMedium;
    }
    return [UIFont systemFontOfSize:MAX(size, 1) weight:weight];
}

@end

@implementation OTLayoutCall

+ (OTLaidOutNode *)layoutRoot:(ParsedNode *)root
                         data:(JSONObject *)data
                     viewport:(CGSize)viewport
                  windowWidth:(CGFloat)windowWidth
                        error:(NSError **)error {
    OTLayoutInput *input = [OTLayoutInput new];
    input.viewport = viewport;
    input.windowWidth = windowWidth;
    input.root = root;
    input.data = [OTData foundation:data];
    return [OTLayoutEngine layoutWithInput:input expression:^id(id expression, id source) {
        return [[ExpressionEngine shared] resultWithExpression:expression data:source];
    } error:error];
}

@end

@implementation OTData

+ (JSONObject *)parseObject:(NSString *)json error:(NSError **)error {
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        if (error) {
            *error = OTParseError(@"数据不是合法 JSON");
        }
        return nil;
    }
    NSError *parseError = nil;
    id raw = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:&parseError];
    if (!raw || ![raw isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = OTParseError(raw ? @"数据必须是 JSON 对象" : @"数据不是合法 JSON");
        }
        return nil;
    }
    return [self objectFromDictionary:raw];
}

+ (JSONObject *)objectFromDictionary:(NSDictionary *)dictionary {
    JSONObject *object = [JSONObject new];
    for (id key in dictionary) {
        if (![key isKindOfClass:[NSString class]]) {
            continue;
        }
        [self setValue:[self valueFromAny:dictionary[key]] forKey:key on:object];
    }
    return object;
}

+ (JSONValue *)valueFromAny:(id)any {
    if (!any || any == NSNull.null) {
        return [JSONValue null];
    }
    if ([any isKindOfClass:[NSString class]]) {
        return [JSONValue string:any];
    }
    if ([any isKindOfClass:[JSONObject class]]) {
        return [JSONValue object:any];
    }
    if ([any isKindOfClass:[JSONArray class]]) {
        return [JSONValue array:any];
    }
    if ([any isKindOfClass:[JSONValue class]]) {
        return any;
    }
    if ([any isKindOfClass:[NSDictionary class]]) {
        return [JSONValue object:[self objectFromDictionary:any]];
    }
    if ([any isKindOfClass:[NSArray class]]) {
        JSONArray *copy = [JSONArray new];
        for (id item in (NSArray *)any) {
            [copy add:[self valueFromAny:item]];
        }
        return [JSONValue array:copy];
    }
    if ([any isKindOfClass:[NSNumber class]]) {
        NSNumber *number = any;
        if (OTIsBoolean(number)) {
            return [JSONValue bool:number.boolValue];
        }
        if (CFNumberIsFloatType((__bridge CFNumberRef)number)) {
            return [JSONValue number:[JSONNumber doubleNumber:number.doubleValue]];
        }
        return [JSONValue number:[JSONNumber intNumber:number.longLongValue]];
    }
    return [JSONValue null];
}

+ (NSDictionary<NSString *, id> *)foundation:(JSONObject *)object {
    if (!object) {
        return @{};
    }
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSString *key in object.keys) {
        id value = [self foundationValue:[object get:key]];
        result[key] = value ?: NSNull.null;
    }
    return result;
}

+ (id)foundationValue:(JSONValue *)value {
    if (!value || value.kind == JSONValueKindNull) {
        return nil;
    }
    switch (value.kind) {
        case JSONValueKindString:
            return value.string ?: @"";
        case JSONValueKindBool:
            return @(value.boolValue);
        case JSONValueKindNumber:
            if (value.number.isDouble) {
                return @(value.number.doubleValue);
            }
            return @(value.number.intValue);
        case JSONValueKindObject:
            return [self foundation:value.jsonObject];
        case JSONValueKindArray: {
            NSMutableArray *items = [NSMutableArray array];
            JSONArray *array = value.jsonArray;
            for (NSInteger index = 0; index < array.size; index++) {
                id item = [self foundationValue:[array get:index]];
                [items addObject:item ?: NSNull.null];
            }
            return items;
        }
        default:
            return nil;
    }
}

+ (NSString *)text:(JSONObject *)object {
    id foundation = [self foundation:object];
    if (![NSJSONSerialization isValidJSONObject:foundation]) {
        return nil;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:foundation options:0 error:nil];
    if (!data) {
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (NSString *)display:(id)value {
    if (!value || value == NSNull.null) {
        return @"null";
    }
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *number = value;
        if (OTIsBoolean(number)) {
            return number.boolValue ? @"true" : @"false";
        }
        return number.stringValue;
    }
    return @"";
}

+ (BOOL)boolText:(id)value {
    if ([value isKindOfClass:[NSNumber class]] && OTIsBoolean((NSNumber *)value)) {
        return [(NSNumber *)value boolValue];
    }
    return [[self display:value] isEqualToString:@"true"];
}

+ (JSONObject *)evaluate:(JSONObject *)raw scope:(JSONObject *)scope {
    NSDictionary *data = [self foundation:scope];
    return [PageParams evaluate:raw resolver:^JSONValue *(NSString *expression) {
        id result = [[ExpressionEngine shared] resultWithExpression:expression data:data];
        return [OTData valueFromAny:result];
    }];
}

+ (JSONObject *)scopePage:(JSONObject *)page item:(JSONObject *)item {
    return [PageParams merge:page overlay:item] ?: [JSONObject new];
}

+ (JSONArray *)listArray:(NSString *)expression data:(JSONObject *)data {
    NSString *trimmed = [expression stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([trimmed hasPrefix:@"$"]) {
        NSString *path = [trimmed substringFromIndex:1];
        if (![path containsString:@"$"]) {
            JSONValue *found = [self lookup:path data:data];
            if (found.kind == JSONValueKindArray && found.jsonArray) {
                return found.jsonArray;
            }
        }
    }
    id result = [[ExpressionEngine shared] resultWithExpression:expression data:[self foundation:data]];
    JSONValue *value = [self valueFromAny:result];
    if (value.kind == JSONValueKindArray && value.jsonArray) {
        return value.jsonArray;
    }
    return [JSONArray new];
}

+ (JSONValue *)lookup:(NSString *)path data:(JSONObject *)data {
    if (!data) {
        return nil;
    }
    JSONValue *current = [JSONValue object:data];
    for (NSString *part in [path componentsSeparatedByString:@"."]) {
        if (part.length == 0) {
            continue;
        }
        if (current.kind != JSONValueKindObject || !current.jsonObject) {
            return nil;
        }
        current = [current.jsonObject get:part] ?: [JSONValue null];
    }
    return current;
}

+ (JSONObject *)deepCopy:(JSONObject *)object {
    if (!object) {
        return nil;
    }
    NSString *text = [self text:object];
    if (!text) {
        return nil;
    }
    return [self parseObject:text error:nil];
}

+ (void)setValue:(JSONValue *)value forKey:(NSString *)key on:(JSONObject *)object {
    if (!object || key.length == 0) {
        return;
    }
    [object set:value ?: [JSONValue null] forKey:key];
}

+ (NSInteger)intValue:(JSONObject *)object key:(NSString *)key {
    JSONValue *value = [object get:key];
    if (value.kind == JSONValueKindNumber) {
        return value.number.intValue;
    }
    if (value.kind == JSONValueKindString) {
        NSString *text = value.string ?: @"";
        if (text.integerValue != 0 || [text isEqualToString:@"0"]) {
            NSScanner *scanner = [NSScanner scannerWithString:text];
            NSInteger whole = 0;
            if ([scanner scanInteger:&whole] && scanner.isAtEnd) {
                return whole;
            }
        }
        return (NSInteger)text.doubleValue;
    }
    return 0;
}

@end
