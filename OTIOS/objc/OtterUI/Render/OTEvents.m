#import "OTEvents.h"
#import "OTNodes.h"
#import "OTStyle.h"
#import "../Engine/OTEngine.h"
#import "../Engine/OTBridge.h"
#import "../Engine/ExpansionCenter.h"
#import "../Nav/PageStack.h"

@interface OTClickTarget : NSObject
@property (class, nonatomic, readonly) OTClickTarget *shared;
- (void)tapped:(UITapGestureRecognizer *)gesture;
@end

@implementation OTEvents

+ (void)attachClick:(UIView *)view names:(NSArray<NSString *> *)names {
    OTBind *bind = [OTViewMark bind:view];
    bind.clickNames = names;
    bind.hasClick = names.count > 0;
    if (names.count == 0) {
        return;
    }
    view.userInteractionEnabled = YES;
    for (UIGestureRecognizer *gesture in view.gestureRecognizers) {
        if ([gesture.name isEqualToString:@"otter.click"]) {
            return;
        }
    }
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:OTClickTarget.shared action:@selector(tapped:)];
    tap.name = @"otter.click";
    tap.delegate = OTClickGate.shared;
    [view addGestureRecognizer:tap];
}

+ (void)fireChange:(UIView *)view {
    OTBind *bind = [OTViewMark bind:view];
    OTTemplateContext *template = bind.template;
    if (!template) {
        return;
    }
    for (NSString *name in bind.changeNames) {
        [self dispatchView:view event:template.events[name] itemData:bind.itemData template:template];
    }
}

+ (void)dispatchView:(UIView *)view event:(JSONObject *)event itemData:(JSONObject *)itemData template:(OTTemplateContext *)template {
    if (!event) {
        return;
    }
    JSONObject *params = [event getJSONObject:@"params"] ?: [JSONObject new];
    NSString *kind = [event getString:@"class"];
    if ([kind isEqualToString:@"util"]) {
        [self util:view params:params item:itemData template:template];
    } else if ([kind isEqualToString:@"view"]) {
        [self viewEvent:view params:params item:itemData template:template];
    } else if ([kind isEqualToString:@"nav"]) {
        [self nav:view params:params item:itemData template:template];
    } else if ([kind isEqualToString:@"list"]) {
        [self list:view params:params item:itemData template:template];
    }
}

+ (NSString *)text:(NSString *)expression data:(JSONObject *)data {
    id result = [[ExpressionEngine shared] resultWithExpression:expression data:[OTData foundation:data]];
    return [OTData display:result];
}

+ (void)util:(UIView *)view params:(JSONObject *)params item:(JSONObject *)item template:(OTTemplateContext *)template {
    if (![[params getString:@"fun"] isEqualToString:@"showToast"]) {
        return;
    }
    NSString *text = [self text:[params getString:@"info"] ?: @"" data:[OTData scopePage:template.data item:item]];
    [OTToast show:text inView:view];
}

+ (void)viewEvent:(UIView *)view params:(JSONObject *)params item:(JSONObject *)item template:(OTTemplateContext *)template {
    if (![[params getString:@"fun"] isEqualToString:@"changeAttributes"]) {
        return;
    }
    JSONObject *merged = [OTData scopePage:template.data item:item];
    NSString *key = [params getString:@"key"];
    if ([key isEqualToString:@"setText"]) {
        UIView *target = [self resolve:view template:template idName:[params getString:@"id"]];
        if (!target) {
            return;
        }
        JSONValue *raw = [params get:@"value"];
        NSString *value = raw.kind == JSONValueKindString ? raw.string : [self text:[OTData display:[OTData foundationValue:raw]] data:merged];
        if ([target isKindOfClass:[OTTextView class]]) {
            ((OTTextView *)target).text = value;
        }
        if ([target conformsToProtocol:@protocol(OTInputting)]) {
            id<OTInputting> input = (id<OTInputting>)target;
            input.suppressChange = YES;
            input.textValue = value ?: @"";
            input.suppressChange = NO;
        }
    } else if ([key isEqualToString:@"setTextStyle"]) {
        UIView *target = [self resolve:view template:template idName:[params getString:@"id"]];
        if (!target) {
            return;
        }
        [self applyStyle:target value:[params getJSONObject:@"value"] data:merged scale:template.scale];
    } else if ([key isEqualToString:@"setChecked"]) {
        BOOL on = [OTData boolText:[self text:[params getString:@"value"] ?: @"false" data:merged]];
        NSArray<NSString *> *names = [[params getString:@"id"] ?: @"" componentsSeparatedByString:@","];
        for (NSString *name in names) {
            NSString *trimmed = [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            UIView *box = [self resolve:view template:template idName:trimmed];
            if (![box conformsToProtocol:@protocol(OTCheckable)]) {
                continue;
            }
            id<OTCheckable> check = (id<OTCheckable>)box;
            if ([box isKindOfClass:[OTRadioView class]] && on) {
                OTRadioView *radio = (OTRadioView *)box;
                [radio setCheckedSilently:YES];
                [radio claimGroup];
                [radio writeSelf];
            } else {
                [check setCheckedSilently:on];
                if ([box isKindOfClass:[OTCheckView class]]) [(OTCheckView *)box writeBack];
                if ([box isKindOfClass:[OTRadioView class]]) [(OTRadioView *)box writeSelf];
                if ([box isKindOfClass:[OTSwitchView class]]) [(OTSwitchView *)box writeBack];
            }
        }
    }
}

+ (void)applyStyle:(UIView *)view value:(JSONObject *)value data:(JSONObject *)data scale:(CGFloat)scale {
    JSONArray *attributes = [value getJSONArray:@"attributes"];
    if (!attributes) {
        return;
    }
    for (NSInteger index = 0; index < attributes.size; index++) {
        JSONObject *style = [attributes getJSONObject:index];
        if (!style) {
            continue;
        }
        NSString *size = [style getString:TemplateKey.ATTR_TEXT_SIZE];
        if (size) {
            UIFont *font = [OTFont fontForFields:@{
                TemplateKey.ATTR_TEXT_SIZE: size,
                TemplateKey.ATTR_FONT_WEIGHT: [style getString:TemplateKey.ATTR_FONT_WEIGHT] ?: @""
            } scale:scale];
            if ([view isKindOfClass:[UILabel class]]) ((UILabel *)view).font = font;
            if ([view isKindOfClass:[UITextField class]]) ((UITextField *)view).font = font;
            if ([view isKindOfClass:[UITextView class]]) ((UITextView *)view).font = font;
        }
        NSString *colorRaw = [style getString:TemplateKey.ATTR_TEXT_COLOR];
        UIColor *color = colorRaw ? [OTColorParser color:[self text:colorRaw data:data]] : nil;
        if (color) {
            if ([view isKindOfClass:[UILabel class]]) ((UILabel *)view).textColor = color;
            if ([view isKindOfClass:[UITextField class]]) ((UITextField *)view).textColor = color;
            if ([view isKindOfClass:[UITextView class]]) ((UITextView *)view).textColor = color;
        }
        NSString *rawText = [style getString:TemplateKey.ATTR_TEXT];
        if (rawText) {
            NSString *shown = [self text:rawText data:data];
            if ([view isKindOfClass:[OTTextView class]]) ((OTTextView *)view).text = shown;
            if ([view conformsToProtocol:@protocol(OTInputting)]) ((id<OTInputting>)view).textValue = shown;
        }
    }
}

+ (void)nav:(UIView *)view params:(JSONObject *)params item:(JSONObject *)item template:(OTTemplateContext *)template {
    JSONObject *merged = [OTData scopePage:template.data item:item];
    NSString *fun = [params getString:@"fun"];
    if ([fun isEqualToString:@"back"]) {
        PageStack *stack = [PageStack find:view];
        if (stack && [stack pop:[params getJSONObject:@"params"]]) {
            return;
        }
        UIViewController *controller = view.ot_controller;
        if (controller.navigationController.viewControllers.count > 1) {
            [controller.navigationController popViewControllerAnimated:YES];
        } else if (controller.presentingViewController) {
            [controller dismissViewControllerAnimated:YES completion:nil];
        }
    } else if ([fun isEqualToString:@"open"]) {
        [self open:view params:params item:item template:template merged:merged replace:NO];
    } else if ([fun isEqualToString:@"replace"]) {
        [self open:view params:params item:item template:template merged:merged replace:YES];
    } else if ([fun isEqualToString:@"popTo"]) {
        NSString *page = [self text:[params getString:@"page"] ?: @"" data:merged];
        PageStack *stack = [PageStack find:view];
        if (stack && page.length > 0 && ![page isEqualToString:@"null"] && [stack popTo:page raw:[params getJSONObject:@"params"]]) {
            return;
        }
        [OTToast show:@"这个页面还打不开" inView:view];
    } else if ([fun isEqualToString:@"host"]) {
        [self host:view params:params merged:merged];
    }
}

+ (void)open:(UIView *)view params:(JSONObject *)params item:(JSONObject *)item template:(OTTemplateContext *)template merged:(JSONObject *)merged replace:(BOOL)replace {
    NSString *page = [self text:[params getString:@"page"] ?: @"" data:merged];
    PageStack *stack = [PageStack find:view];
    if (stack) {
        if (page.length == 0 || [page isEqualToString:@"null"]) {
            [OTToast show:@"这个页面还打不开" inView:view];
            return;
        }
        JSONObject *raw = [params getJSONObject:@"params"];
        if (replace) {
            [stack replace:page raw:raw item:item pageData:template.data];
        } else {
            [stack open:page raw:raw item:item pageData:template.data];
        }
        return;
    }
    void (^opener)(UIViewController *, NSString *) = ExpansionCenter.shared.pageOpener;
    if (!opener || page.length == 0 || [page isEqualToString:@"null"]) {
        [OTToast show:@"这个页面还打不开" inView:view];
        return;
    }
    opener(view.ot_controller ?: [UIViewController new], page);
}

+ (void)host:(UIView *)view params:(JSONObject *)params merged:(JSONObject *)merged {
    NSString *name = [self text:[params getString:@"name"] ?: @"" data:merged];
    if (name.length == 0 || [name isEqualToString:@"null"]) {
        [OTToast show:@"这个操作还不能用" inView:view];
        return;
    }
    JSONObject *raw = [params getJSONObject:@"params"];
    JSONObject *evaluated = raw ? [OTData evaluate:raw scope:merged] : nil;
    if (![[ExpansionCenter shared] dispatchHost:view name:name params:evaluated]) {
        [OTToast show:@"这个操作还不能用" inView:view];
    }
}

+ (void)list:(UIView *)view params:(JSONObject *)params item:(JSONObject *)item template:(OTTemplateContext *)template {
    NSString *fun = [params getString:@"fun"];
    if ([fun isEqualToString:@"append"]) {
        [self append:view params:params template:template];
    } else if ([fun isEqualToString:@"update"]) {
        [self update:view params:params item:item template:template];
    } else if ([fun isEqualToString:@"remove"]) {
        [self remove:view params:params item:item template:template];
    }
}

+ (void)append:(UIView *)view params:(JSONObject *)params template:(OTTemplateContext *)template {
    UIView *inputView = [self resolve:view template:template idName:[params getString:@"from"]];
    if (![inputView conformsToProtocol:@protocol(OTInputting)]) {
        return;
    }
    id<OTInputting> input = (id<OTInputting>)inputView;
    NSString *typed = [input.textValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (typed.length == 0) {
        NSString *empty = [params getString:@"empty"] ?: @"";
        if (empty.length > 0) {
            [OTToast show:empty inView:view];
        }
        return;
    }
    UIView *list = [self resolve:view template:template idName:[params getString:@"id"]];
    if (![list isKindOfClass:[OTListView class]]) {
        return;
    }
    OTListView *listView = (OTListView *)list;
    JSONObject *item = [JSONObject new];
    JSONObject *fields = [params getJSONObject:@"item"];
    for (NSString *key in fields.keys) {
        [OTData setValue:[JSONValue string:[fields getString:key] ?: @""] forKey:key on:item];
    }
    NSString *field = [params getString:@"field"];
    if (field) {
        [OTData setValue:[JSONValue string:typed] forKey:field on:item];
    }
    NSString *key = [params getString:@"data"];
    JSONArray *stored = key ? [template.data getJSONArray:key] : nil;
    if (stored && stored != listView.items) {
        [stored add:[JSONValue object:item]];
    }
    [listView.items add:[JSONValue object:item]];
    NSInteger last = MAX((NSInteger)listView.items.size - 1, 0);
    [listView reloadData];
    if (listView.items.size > 0) {
        [listView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:last inSection:0]
                         atScrollPosition:listView.horizontal ? UICollectionViewScrollPositionCenteredHorizontally : UICollectionViewScrollPositionCenteredVertically
                                 animated:YES];
    }
    input.suppressChange = YES;
    input.textValue = @"";
    input.suppressChange = NO;
    NSString *inputId = [OTViewMark bind:(UIView *)input].idName;
    if (inputId) {
        [OTData setValue:[JSONValue string:@""] forKey:inputId on:template.data];
    }
    [OTIme dismiss:(UIView *)input];
}

+ (void)update:(UIView *)view params:(JSONObject *)params item:(JSONObject *)item template:(OTTemplateContext *)template {
    NSNumber *index = [self resolveIndex:params item:item page:template.data];
    JSONObject *fields = [params getJSONObject:@"item"];
    if (!index || !fields) {
        return;
    }
    UIView *list = [self resolve:view template:template idName:[params getString:@"id"]];
    if (![list isKindOfClass:[OTListView class]]) {
        return;
    }
    OTListView *listView = (OTListView *)list;
    if (index.integerValue < 0 || index.integerValue >= listView.items.size) {
        return;
    }
    JSONObject *target = [listView.items getJSONObject:index.integerValue];
    if (!target) {
        return;
    }
    JSONObject *merged = [OTData scopePage:template.data item:item];
    for (NSString *key in fields.keys) {
        [OTData setValue:[JSONValue string:[self text:[fields getString:key] ?: @"" data:merged]] forKey:key on:target];
    }
    [listView reloadItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:index.integerValue inSection:0]]];
}

+ (void)remove:(UIView *)view params:(JSONObject *)params item:(JSONObject *)item template:(OTTemplateContext *)template {
    NSNumber *index = [self resolveIndex:params item:item page:template.data];
    if (!index) {
        return;
    }
    UIView *list = [self resolve:view template:template idName:[params getString:@"id"]];
    if (![list isKindOfClass:[OTListView class]]) {
        return;
    }
    OTListView *listView = (OTListView *)list;
    if (index.integerValue < 0 || index.integerValue >= listView.items.size) {
        return;
    }
    JSONArray *kept = [JSONArray new];
    for (NSInteger cursor = 0; cursor < listView.items.size; cursor++) {
        if (cursor == index.integerValue) {
            continue;
        }
        JSONValue *value = [listView.items get:cursor];
        if (value) {
            [kept add:value];
        }
    }
    if (listView.dataKey) {
        [OTData setValue:[JSONValue array:kept] forKey:listView.dataKey on:template.data];
    }
    listView.items = kept;
    [listView reloadData];
}

+ (NSNumber *)resolveIndex:(JSONObject *)params item:(JSONObject *)item page:(JSONObject *)page {
    NSString *raw = [params getString:@"index"];
    if (raw.length == 0) {
        return nil;
    }
    NSString *text = [self text:raw data:[OTData scopePage:page item:item]];
    NSScanner *scanner = [NSScanner scannerWithString:text];
    NSInteger value = 0;
    if (![scanner scanInteger:&value] || !scanner.isAtEnd) {
        return nil;
    }
    return @(value);
}

+ (UIView *)resolve:(UIView *)view template:(OTTemplateContext *)template idName:(NSString *)idName {
    if (idName.length == 0) {
        return nil;
    }
    if ([[OTViewMark bind:view].idName isEqualToString:idName]) {
        return view;
    }
    return [self find:template.rootView idName:idName];
}

+ (UIView *)find:(UIView *)view idName:(NSString *)idName {
    if (!view) {
        return nil;
    }
    if ([[OTViewMark bind:view].idName isEqualToString:idName]) {
        return view;
    }
    if ([view isKindOfClass:[OTColumnView class]]) {
        for (UIView *child in ((OTColumnView *)view).templateChildren) {
            UIView *found = [self find:child idName:idName];
            if (found) {
                return found;
            }
        }
    }
    for (UIView *child in view.subviews) {
        UIView *found = [self find:child idName:idName];
        if (found) {
            return found;
        }
    }
    return nil;
}

@end

@implementation OTClickTarget

+ (OTClickTarget *)shared {
    static OTClickTarget *target;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ target = [OTClickTarget new]; });
    return target;
}

- (void)tapped:(UITapGestureRecognizer *)gesture {
    UIView *view = gesture.view;
    if (!view) {
        return;
    }
    OTBind *bind = [OTViewMark bind:view];
    OTTemplateContext *template = bind.template;
    if (!template) {
        return;
    }
    for (NSString *name in bind.clickNames) {
        [OTEvents dispatchView:view event:template.events[name] itemData:bind.itemData template:template];
    }
    if (bind.itemData && ExpansionCenter.shared.itemClick) {
        NSMutableDictionary<NSString *, NSString *> *map = [NSMutableDictionary dictionary];
        for (NSString *key in bind.itemData.keys) {
            JSONValue *value = [bind.itemData get:key];
            if (value.kind == JSONValueKindString && value.string) {
                map[key] = value.string;
            }
        }
        ExpansionCenter.shared.itemClick(map);
    }
}

@end
