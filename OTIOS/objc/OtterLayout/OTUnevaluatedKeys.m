#import "OTUnevaluatedKeys.h"

#import "TemplateKey.h"

@implementation OTUnevaluatedKeys

+ (NSSet<NSString *> *)names {
    static NSSet<NSString *> *names;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = [NSSet setWithObjects:
            [TemplateKey ATTR_ONCLICK],
            [TemplateKey ATTR_ONCHANGE],
            [TemplateKey ATTR_ALIGN_SELF],
            [TemplateKey FLEXBOX_ATTR_JUSTIFY_CONTENT],
            [TemplateKey FLEXBOX_ATTR_ALIGN_ITEMS],
            [TemplateKey ATTR_FLEX_WRAP],
            [TemplateKey ATTR_SCROLL],
            nil];
    });
    return names;
}

+ (BOOL)containsName:(NSString *)name {
    if (name.length == 0) {
        return NO;
    }
    return [[self names] containsObject:name];
}

@end
