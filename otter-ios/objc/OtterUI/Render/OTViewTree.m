#import "OTViewTree.h"
#import "OTNodes.h"
#import "OTEvents.h"
#import "OTStyle.h"
#import "../Engine/OTEngine.h"
#import "../Engine/OTBridge.h"

@implementation OTViewTree

+ (OTAbsoluteView *)contentHost:(UIView *)view {
    if ([view isKindOfClass:[OTColumnView class]] && ((OTColumnView *)view).scrolling) {
        return ((OTColumnView *)view).scrollContent;
    }
    if ([view isKindOfClass:[OTAbsoluteView class]]) {
        return (OTAbsoluteView *)view;
    }
    return nil;
}

+ (UIView *)buildParsed:(ParsedNode *)parsed laid:(OTLaidOutNode *)laid template:(OTTemplateContext *)template itemData:(JSONObject *)itemData error:(NSError **)error {
    UIView *view = [self make:parsed laid:laid template:template itemData:itemData error:error];
    if (!view) {
        return nil;
    }
    OTAbsoluteView *container = [self contentHost:view];
    if (container) {
        NSInteger count = MIN((NSInteger)parsed.children.count, (NSInteger)laid.children.count);
        for (NSInteger index = 0; index < count; index++) {
            UIView *childView = [self buildParsed:parsed.children[index] laid:laid.children[index] template:template itemData:itemData error:error];
            if (!childView) {
                return nil;
            }
            [container.templateChildren addObject:childView];
            [container addSubview:childView];
        }
        [container placeChildren];
    }
    if ([parsed.viewName isEqualToString:TemplateKey.OT_LIST] && [view isKindOfClass:[OTListView class]]) {
        [self configureList:(OTListView *)view parsed:parsed template:template];
    }
    return view;
}

+ (BOOL)rebindView:(UIView *)view parsed:(ParsedNode *)parsed laid:(OTLaidOutNode *)laid template:(OTTemplateContext *)template error:(NSError **)error {
    [self fill:view parsed:parsed laid:laid template:template itemData:nil];
    if ([parsed.viewName isEqualToString:TemplateKey.OT_LIST]) {
        if ([view isKindOfClass:[OTListView class]]) {
            [self configureList:(OTListView *)view parsed:parsed template:template];
        }
        return YES;
    }
    OTAbsoluteView *container = [self contentHost:view];
    if (!container) {
        return YES;
    }
    NSInteger count = MIN((NSInteger)container.templateChildren.count, MIN((NSInteger)parsed.children.count, (NSInteger)laid.children.count));
    for (NSInteger index = 0; index < count; index++) {
        if (![self rebindView:container.templateChildren[index] parsed:parsed.children[index] laid:laid.children[index] template:template error:error]) {
            return NO;
        }
    }
    return YES;
}

+ (void)applyFrames:(UIView *)view laid:(OTLaidOutNode *)laid {
    [OTViewMark bind:view].otterFrame = laid.frame;
    view.frame = laid.frame;
    if ([laid.viewName isEqualToString:TemplateKey.OT_LIST]) {
        return;
    }
    OTAbsoluteView *container = [self contentHost:view];
    if (!container) {
        return;
    }
    NSInteger count = MIN((NSInteger)container.templateChildren.count, (NSInteger)laid.children.count);
    for (NSInteger index = 0; index < count; index++) {
        [self applyFrames:container.templateChildren[index] laid:laid.children[index]];
    }
    [container placeChildren];
    if ([view isKindOfClass:[OTColumnView class]] && ((OTColumnView *)view).scrolling) {
        [(OTColumnView *)view placeChildren];
    }
}

+ (UIView *)make:(ParsedNode *)parsed laid:(OTLaidOutNode *)laid template:(OTTemplateContext *)template itemData:(JSONObject *)itemData error:(NSError **)error {
    UIView *view = nil;
    NSString *name = parsed.viewName;
    if ([name isEqualToString:TemplateKey.COLUMN]) {
        OTColumnView *column = [OTColumnView new];
        if ([parsed.attrs[TemplateKey.ATTR_SCROLL] isEqualToString:@"true"]) {
            [column ensureScroll];
        }
        view = column;
    } else if ([name isEqualToString:TemplateKey.ROW]) {
        view = [OTRowView new];
    } else if ([name isEqualToString:TemplateKey.TEXT]) {
        view = [OTTextView new];
    } else if ([name isEqualToString:TemplateKey.IMAGE]) {
        view = [OTImageView new];
    } else if ([name isEqualToString:TemplateKey.SPACER]) {
        view = [OTSpacerView new];
    } else if ([name isEqualToString:TemplateKey.OT_LIST]) {
        view = [[OTListView alloc] init];
    } else if ([name isEqualToString:TemplateKey.PROGRESS]) {
        view = [OTProgressView new];
    } else if ([name isEqualToString:TemplateKey.ANIMATION]) {
        view = [OTLottieView new];
    } else if ([name isEqualToString:TemplateKey.INPUT]) {
        NSInteger lines = parsed.attrs[TemplateKey.ATTR_LINES].integerValue ?: 1;
        view = lines > 1 ? [OTInputArea new] : [OTInputView new];
    } else if ([name isEqualToString:TemplateKey.CHECKBOX]) {
        view = [OTCheckView new];
    } else if ([name isEqualToString:TemplateKey.RADIO]) {
        view = [OTRadioView new];
    } else if ([name isEqualToString:TemplateKey.SWITCH]) {
        view = [OTSwitchView new];
    } else {
        if (error) {
            *error = OTParseError([NSString stringWithFormat:@"type「%@」无法识别", parsed.viewName]);
        }
        return nil;
    }
    [OTViewMark bind:view].otterFrame = laid.frame;
    view.frame = laid.frame;
    [self fill:view parsed:parsed laid:laid template:template itemData:itemData];
    return view;
}

+ (NSArray<NSString *> *)names:(NSString *)raw {
    if (raw.length == 0) {
        return @[];
    }
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSString *part in [raw componentsSeparatedByString:@","]) {
        NSString *trimmed = [part stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (trimmed.length > 0) {
            [names addObject:trimmed];
        }
    }
    return names;
}

+ (void)fill:(UIView *)view parsed:(ParsedNode *)parsed laid:(OTLaidOutNode *)laid template:(OTTemplateContext *)template itemData:(JSONObject *)itemData {
    (void)laid;
    OTBind *bind = [OTViewMark bind:view];
    bind.template = template;
    bind.itemData = itemData;
    bind.fields = parsed.attrs ?: @{};
    bind.scale = template.scale;
    bind.parsed = parsed;
    JSONObject *scope = itemData ?: template.data;
    NSString *identifier = parsed.attrs[TemplateKey.ATTR_ID];
    if (identifier) {
        bind.idName = identifier;
        view.accessibilityIdentifier = identifier;
        template.viewIds[identifier] = view;
    }
    NSString *visible = [OTChrome eval:parsed.attrs[TemplateKey.ATTR_VISIBLE] data:scope] ?: @"true";
    view.hidden = [visible isEqualToString:@"false"];
    [OTChrome applyView:view fields:parsed.attrs scale:template.scale itemData:scope];
    [OTEvents attachClick:view names:[self names:parsed.attrs[TemplateKey.ATTR_ONCLICK]]];
    bind.changeNames = [self names:parsed.attrs[TemplateKey.ATTR_ONCHANGE]];
    [self push:view parsed:parsed scope:scope template:template];
}

+ (void)push:(UIView *)view parsed:(ParsedNode *)parsed scope:(JSONObject *)scope template:(OTTemplateContext *)template {
    NSDictionary<NSString *, NSString *> *fields = parsed.attrs ?: @{};
    if ([view isKindOfClass:[OTTextView class]]) {
        [self bindText:(OTTextView *)view fields:fields scope:scope scale:template.scale];
    } else if ([view isKindOfClass:[OTImageView class]]) {
        OTImageView *image = (OTImageView *)view;
        image.fit = fields[TemplateKey.ATTR_IMAGE_FIT] ?: @"cover";
        image.placeholder = [OTColorParser color:[OTChrome eval:fields[TemplateKey.ATTR_PLACEHOLDER] data:scope]];
        [image load:[OTChrome eval:fields[TemplateKey.ATTR_SRC] data:scope] ?: @""];
    } else if ([view isKindOfClass:[OTInputView class]]) {
        [self bindInput:(OTInputView *)view fields:fields scope:scope scale:template.scale];
    } else if ([view isKindOfClass:[OTInputArea class]]) {
        [self bindArea:(OTInputArea *)view fields:fields scope:scope scale:template.scale];
    } else if ([view isKindOfClass:[OTCheckView class]]) {
        [self bindCheck:(OTCheckView *)view fields:fields scope:scope scale:template.scale];
    } else if ([view isKindOfClass:[OTRadioView class]]) {
        [self bindRadio:(OTRadioView *)view fields:fields scope:scope scale:template.scale];
    } else if ([view isKindOfClass:[OTSwitchView class]]) {
        [self bindSwitch:(OTSwitchView *)view fields:fields scope:scope scale:template.scale];
    } else if ([view isKindOfClass:[OTProgressView class]]) {
        OTProgressView *progress = (OTProgressView *)view;
        CGFloat from = [OTChrome eval:fields[TemplateKey.ATTR_VALUE_MIN] ?: @"0" data:scope].doubleValue;
        CGFloat to = [OTChrome eval:fields[TemplateKey.ATTR_VALUE_MAX] ?: @"1" data:scope].doubleValue;
        progress.trackColor = [OTColorParser color:[OTChrome eval:fields[TemplateKey.ATTR_STROKE_COLOR] data:scope]] ?: UIColor.grayColor;
        progress.barColor = [OTColorParser color:[OTChrome eval:fields[TemplateKey.ATTR_TRAIL_COLOR] data:scope]] ?: UIColor.redColor;
        [progress bindFrom:from to:to animate:[fields[TemplateKey.ATTR_ANIMATE_ENABLE] isEqualToString:@"true"]];
    } else if ([view isKindOfClass:[OTLottieView class]]) {
        [(OTLottieView *)view bindSrc:fields[TemplateKey.ATTR_ANIMATION_SRC] ?: @""
                         repeatCount:fields[TemplateKey.ATTR_ANI_REPEAT_COUNT] ?: @"infinite"
                                mode:fields[TemplateKey.ATTR_ANI_REPEAT_MODE] ?: @"restart"
                            autoPlay:[(fields[TemplateKey.ATTR_ANI_AUTO_PLAY] ?: @"true") isEqualToString:@"true"]];
    }
}

+ (void)bindText:(OTTextView *)label fields:(NSDictionary<NSString *, NSString *> *)fields scope:(JSONObject *)scope scale:(CGFloat)scale {
    label.text = [OTChrome eval:fields[TemplateKey.ATTR_TEXT] data:scope] ?: @"";
    label.textColor = [OTColorParser color:[OTChrome eval:fields[TemplateKey.ATTR_TEXT_COLOR] data:scope]] ?: UIColor.blackColor;
    label.font = [OTFont fontForFields:fields scale:scale];
    label.numberOfLines = [self lineLimit:fields];
    label.lineBreakMode = [fields[TemplateKey.ATTR_ELLIPSIS] isEqualToString:@"true"] ? NSLineBreakByTruncatingTail : NSLineBreakByWordWrapping;
    BOOL wrap = [fields[TemplateKey.ATTR_HEIGHT] isEqualToString:TemplateKey.OT_WRAP_CONTENT];
    NSString *align = fields[TemplateKey.ATTR_TEXT_ALIGN];
    if ([align isEqualToString:@"center"]) label.textAlignment = NSTextAlignmentCenter;
    else if ([align isEqualToString:@"end"]) label.textAlignment = NSTextAlignmentRight;
    else label.textAlignment = NSTextAlignmentLeft;
    if (wrap || !align) {
        label.baselineAdjustment = UIBaselineAdjustmentAlignBaselines;
    }
    label.textInset = [self padding:fields scale:scale];
}

+ (NSInteger)lineLimit:(NSDictionary<NSString *, NSString *> *)fields {
    NSString *raw = fields[TemplateKey.ATTR_MAX_LINES];
    if (raw.integerValue > 0) {
        return raw.integerValue;
    }
    if ([fields[TemplateKey.ATTR_ELLIPSIS] isEqualToString:@"true"]) {
        return 1;
    }
    return 0;
}

+ (void)bindInput:(OTInputView *)input fields:(NSDictionary<NSString *, NSString *> *)fields scope:(JSONObject *)scope scale:(CGFloat)scale {
    input.suppressChange = YES;
    input.font = [OTFont fontForFields:fields scale:scale];
    input.textColor = [OTColorParser color:[OTChrome eval:fields[TemplateKey.ATTR_TEXT_COLOR] data:scope]] ?: [OTColorParser color:@"#1F1A17"];
    input.textValue = [OTChrome eval:fields[TemplateKey.ATTR_TEXT] data:scope] ?: @"";
    input.placeholder = [OTChrome eval:fields[TemplateKey.ATTR_HINT] data:scope];
    UIColor *hintColor = [OTColorParser color:[OTChrome eval:fields[TemplateKey.ATTR_HINT_COLOR] data:scope]];
    if (input.placeholder && hintColor) {
        input.attributedPlaceholder = [[NSAttributedString alloc] initWithString:input.placeholder attributes:@{NSForegroundColorAttributeName: hintColor}];
    }
    NSString *maxLength = fields[TemplateKey.ATTR_MAX_LENGTH];
    input.maxLength = maxLength ? @(maxLength.integerValue) : nil;
    [self applyKeyboard:input type:fields[TemplateKey.ATTR_INPUT_TYPE] ?: @"text"];
    NSString *align = fields[TemplateKey.ATTR_TEXT_ALIGN];
    if ([align isEqualToString:@"center"]) input.textAlignment = NSTextAlignmentCenter;
    else if ([align isEqualToString:@"end"]) input.textAlignment = NSTextAlignmentRight;
    else input.textAlignment = NSTextAlignmentLeft;
    input.suppressChange = NO;
}

+ (void)bindArea:(OTInputArea *)area fields:(NSDictionary<NSString *, NSString *> *)fields scope:(JSONObject *)scope scale:(CGFloat)scale {
    area.suppressChange = YES;
    area.font = [OTFont fontForFields:fields scale:scale];
    area.textColor = [OTColorParser color:[OTChrome eval:fields[TemplateKey.ATTR_TEXT_COLOR] data:scope]] ?: [OTColorParser color:@"#1F1A17"];
    area.textValue = [OTChrome eval:fields[TemplateKey.ATTR_TEXT] data:scope] ?: @"";
    NSString *maxLength = fields[TemplateKey.ATTR_MAX_LENGTH];
    area.maxLength = maxLength ? @(maxLength.integerValue) : nil;
    NSString *align = fields[TemplateKey.ATTR_TEXT_ALIGN];
    if ([align isEqualToString:@"center"]) area.textAlignment = NSTextAlignmentCenter;
    else if ([align isEqualToString:@"end"]) area.textAlignment = NSTextAlignmentRight;
    else area.textAlignment = NSTextAlignmentLeft;
    area.suppressChange = NO;
}

+ (void)applyKeyboard:(UITextField *)input type:(NSString *)type {
    input.secureTextEntry = NO;
    if ([type isEqualToString:@"number"]) input.keyboardType = UIKeyboardTypeNumberPad;
    else if ([type isEqualToString:@"password"]) {
        input.keyboardType = UIKeyboardTypeDefault;
        input.secureTextEntry = YES;
    } else if ([type isEqualToString:@"email"]) input.keyboardType = UIKeyboardTypeEmailAddress;
    else if ([type isEqualToString:@"phone"]) input.keyboardType = UIKeyboardTypePhonePad;
    else input.keyboardType = UIKeyboardTypeDefault;
}

+ (NSDictionary *)merged:(NSDictionary<NSString *, NSString *> *)fields size:(NSString *)size {
    NSMutableDictionary *copy = [fields mutableCopy] ?: [NSMutableDictionary dictionary];
    if (!copy[TemplateKey.ATTR_TEXT_SIZE]) {
        copy[TemplateKey.ATTR_TEXT_SIZE] = size;
    }
    return copy;
}

+ (void)bindCheck:(OTCheckView *)box fields:(NSDictionary<NSString *, NSString *> *)fields scope:(JSONObject *)scope scale:(CGFloat)scale {
    BOOL checked = [[OTChrome eval:fields[TemplateKey.ATTR_CHECKED] data:scope] ?: @"false" isEqualToString:@"true"];
    [box setCheckedSilently:checked];
    box.label.text = [OTChrome eval:fields[TemplateKey.ATTR_TEXT] data:scope] ?: @"";
    box.label.font = [OTFont fontForFields:[self merged:fields size:@"14"] scale:scale];
    box.label.textColor = [OTColorParser color:[OTChrome eval:fields[TemplateKey.ATTR_TEXT_COLOR] data:scope]] ?: [OTColorParser color:@"#1F1A17"];
    UIColor *tint = [OTColorParser color:[OTChrome eval:fields[TemplateKey.ATTR_TINT] data:scope]] ?: [OTColorParser color:@"#1F6F6A"] ?: UIColor.systemTealColor;
    box.box.layer.borderWidth = 1.5;
    box.box.layer.borderColor = tint.CGColor;
    box.box.backgroundColor = checked ? tint : UIColor.clearColor;
    box.mark.strokeColor = UIColor.whiteColor.CGColor;
}

+ (void)bindRadio:(OTRadioView *)radio fields:(NSDictionary<NSString *, NSString *> *)fields scope:(JSONObject *)scope scale:(CGFloat)scale {
    radio.groupName = [OTChrome eval:fields[TemplateKey.ATTR_GROUP] data:scope] ?: @"";
    BOOL checked = [[OTChrome eval:fields[TemplateKey.ATTR_CHECKED] data:scope] ?: @"false" isEqualToString:@"true"];
    [radio setCheckedSilently:checked];
    radio.label.text = [OTChrome eval:fields[TemplateKey.ATTR_TEXT] data:scope] ?: @"";
    radio.label.font = [OTFont fontForFields:[self merged:fields size:@"14"] scale:scale];
    radio.label.textColor = [OTColorParser color:[OTChrome eval:fields[TemplateKey.ATTR_TEXT_COLOR] data:scope]] ?: [OTColorParser color:@"#1F1A17"];
    UIColor *tint = [OTColorParser color:[OTChrome eval:fields[TemplateKey.ATTR_TINT] data:scope]] ?: [OTColorParser color:@"#1F6F6A"] ?: UIColor.systemTealColor;
    radio.dot.layer.borderColor = tint.CGColor;
    radio.dot.backgroundColor = UIColor.clearColor;
}

+ (void)bindSwitch:(OTSwitchView *)toggle fields:(NSDictionary<NSString *, NSString *> *)fields scope:(JSONObject *)scope scale:(CGFloat)scale {
    BOOL checked = [[OTChrome eval:fields[TemplateKey.ATTR_CHECKED] data:scope] ?: @"false" isEqualToString:@"true"];
    [toggle setCheckedSilently:checked];
    toggle.label.text = [OTChrome eval:fields[TemplateKey.ATTR_TEXT] data:scope] ?: @"";
    toggle.label.font = [OTFont fontForFields:[self merged:fields size:@"14"] scale:scale];
    toggle.label.textColor = [OTColorParser color:[OTChrome eval:fields[TemplateKey.ATTR_TEXT_COLOR] data:scope]] ?: [OTColorParser color:@"#1F1A17"];
    UIColor *tint = [OTColorParser color:[OTChrome eval:fields[TemplateKey.ATTR_TINT] data:scope]];
    if (tint) {
        toggle.track.onTintColor = tint;
    }
}

+ (UIEdgeInsets)padding:(NSDictionary<NSString *, NSString *> *)fields scale:(CGFloat)scale {
    CGFloat (^edge)(NSString *) = ^CGFloat(NSString *specific) {
        NSNumber *value = [OTMeasure points:fields[specific] ?: fields[TemplateKey.ATTR_PADDING] scale:scale];
        return value ? value.doubleValue : 0;
    };
    return UIEdgeInsetsMake(edge(TemplateKey.ATTR_PADDING_TOP), edge(TemplateKey.ATTR_PADDING_START), edge(TemplateKey.ATTR_PADDING_BOTTOM), edge(TemplateKey.ATTR_PADDING_END));
}

+ (void)configureList:(OTListView *)list parsed:(ParsedNode *)parsed template:(OTTemplateContext *)template {
    list.template = template;
    list.itemTemplate = parsed.item;
    list.windowWidth = template.viewport.width;
    NSNumber *gap = [OTMeasure points:parsed.attrs[TemplateKey.ATTR_ITEM_PADDING] ?: @"0" scale:template.scale];
    [list applyDirection:parsed.attrs[TemplateKey.ATTR_LIST_DIRECTION] ?: TemplateKey.OT_VERTICAL gap:gap.doubleValue];
    NSString *expression = parsed.attrs[TemplateKey.ATTR_DATA] ?: @"";
    NSString *trimmed = [expression stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *key = [trimmed hasPrefix:@"$"] ? [trimmed substringFromIndex:1] : nil;
    if ([key containsString:@"."]) {
        key = nil;
    }
    [list setItems:[OTData listArray:expression data:template.data] key:key];
}

@end
