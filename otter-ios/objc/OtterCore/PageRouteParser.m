#import "PageRouteParser.h"
#import "JSONValue.h"
#import "PageParams.h"

@implementation PageRoute

- (instancetype)initWithTemplate:(NSString *)template data:(NSString *)data {
    self = [super init];
    if (self != nil) {
        _template = [template copy];
        _data = [data copy];
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[PageRoute class]]) {
        return NO;
    }
    PageRoute *other = object;
    BOOL sameData = self.data == other.data || [self.data isEqualToString:other.data];
    return [self.template isEqualToString:other.template] && sameData;
}

- (NSUInteger)hash {
    return self.template.hash ^ self.data.hash;
}

@end

@implementation PageRouteTable

- (instancetype)initWithStart:(NSString *)start pages:(NSDictionary<NSString *, PageRoute *> *)pages {
    self = [super init];
    if (self != nil) {
        _start = [start copy];
        _pages = [pages copy];
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[PageRouteTable class]]) {
        return NO;
    }
    PageRouteTable *other = object;
    return [self.start isEqualToString:other.start] && [self.pages isEqualToDictionary:other.pages];
}

- (NSUInteger)hash {
    return self.start.hash ^ self.pages.hash;
}

@end

@implementation PageRouteParser

+ (PageRouteTable *)parseJSON:(NSString *)json error:(NSError **)error {
    JSONObject *root = [JSONReader rootObjectFromJSON:json
                                        invalidPrefix:@"路由不是合法 JSON："
                                            notObject:@"路由必须是 JSON 对象"
                                                error:error];
    if (root == nil) {
        return nil;
    }
    if (![JSONReader requireKeys:root
                            path:@"$"
                         allowed:[NSSet setWithObjects:@"start", @"pages", nil]
                        required:@[@"start", @"pages"]
                           error:error]) {
        return nil;
    }
    NSString *start = [JSONReader requireString:[root get:@"start"] path:@"$.start" error:error];
    if (start == nil) {
        return nil;
    }
    if (![JSONText isName:start]) {
        if (error != NULL) {
            *error = TemplateParseExceptionError(
                [NSString stringWithFormat:@"$.start「%@」必须是字母或下划线开头的标识符", start]);
        }
        return nil;
    }
    JSONObject *pagesObject = [JSONReader requireObject:[root get:@"pages"] path:@"$.pages" error:error];
    if (pagesObject == nil) {
        return nil;
    }
    if (pagesObject.isEmpty) {
        if (error != NULL) {
            *error = TemplateParseExceptionError(@"$.pages 不能是空对象");
        }
        return nil;
    }
    NSMutableDictionary<NSString *, PageRoute *> *pages = [NSMutableDictionary dictionary];
    for (NSString *name in pagesObject.keys) {
        if (![JSONText isName:name]) {
            if (error != NULL) {
                *error = TemplateParseExceptionError(
                    [NSString stringWithFormat:@"$.pages 的页面名「%@」必须是字母或下划线开头的标识符", name]);
            }
            return nil;
        }
        NSString *pagePath = [NSString stringWithFormat:@"$.pages.%@", name];
        JSONObject *page = [JSONReader requireObject:[pagesObject get:name] path:pagePath error:error];
        if (page == nil) {
            return nil;
        }
        if (![JSONReader requireKeys:page
                                path:pagePath
                             allowed:[NSSet setWithObjects:@"template", @"data", nil]
                            required:@[@"template"]
                               error:error]) {
            return nil;
        }
        NSString *templatePath = [pagePath stringByAppendingString:@".template"];
        NSString *template = [JSONReader requireString:[page get:@"template"] path:templatePath error:error];
        if (template == nil) {
            return nil;
        }
        if (template.length == 0) {
            if (error != NULL) {
                *error = TemplateParseExceptionError([templatePath stringByAppendingString:@" 不能是空字符串"]);
            }
            return nil;
        }
        NSString *data = nil;
        if ([page containsKey:@"data"]) {
            NSString *dataPath = [pagePath stringByAppendingString:@".data"];
            NSString *dataPathValue = [JSONReader requireString:[page get:@"data"] path:dataPath error:error];
            if (dataPathValue == nil) {
                return nil;
            }
            if (dataPathValue.length == 0) {
                if (error != NULL) {
                    *error = TemplateParseExceptionError([dataPath stringByAppendingString:@" 不能是空字符串"]);
                }
                return nil;
            }
            data = dataPathValue;
        }
        pages[name] = [[PageRoute alloc] initWithTemplate:template data:data];
    }
    if (pages[start] == nil) {
        if (error != NULL) {
            *error = TemplateParseExceptionError(
                [NSString stringWithFormat:@"$.start 引用了不存在的页面 %@", start]);
        }
        return nil;
    }
    return [[PageRouteTable alloc] initWithStart:start pages:pages];
}

@end
