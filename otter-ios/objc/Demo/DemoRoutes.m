#import "DemoRoutes.h"
#import "ComponentDemoController.h"
#import "MarketController.h"
#import "PermissionController.h"
#import "StackController.h"
#import "WeatherCardController.h"
#import "../OtterUI/Engine/OTBridge.h"
#import "../OtterUI/Nav/PageStack.h"
#import "../OtterUI/Render/OTNodes.h"

static UIColor *DemoInk(void) {
    return [UIColor colorWithRed:0x1F / 255.0 green:0x1A / 255.0 blue:0x17 / 255.0 alpha:1];
}

@implementation DemoTopBar {
    UIButton *_back;
    UILabel *_title;
    UIView *_hairline;
    BOOL _showsBack;
}

+ (CGFloat)barHeight {
    return 49;
}

+ (instancetype)barWithTitle:(NSString *)title showsBack:(BOOL)showsBack {
    DemoTopBar *bar = [DemoTopBar new];
    bar.backgroundColor = [UIColor colorWithRed:0xFF / 255.0 green:0xFC / 255.0 blue:0xF8 / 255.0 alpha:1];
    bar->_showsBack = showsBack;
    UIButton *back = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *icon = [[OTAssets imageNamed:@"ic_back"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    [back setImage:icon forState:UIControlStateNormal];
    back.contentEdgeInsets = UIEdgeInsetsMake(12, 12, 12, 12);
    back.accessibilityLabel = @"返回";
    back.hidden = !showsBack;
    [back addTarget:bar action:@selector(backTapped) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:back];
    UILabel *label = [UILabel new];
    label.text = title;
    label.textColor = DemoInk();
    label.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    label.numberOfLines = 1;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    [bar addSubview:label];
    UIView *hairline = [UIView new];
    hairline.backgroundColor = [UIColor colorWithRed:0xE6 / 255.0 green:0xDD / 255.0 blue:0xD2 / 255.0 alpha:1];
    [bar addSubview:hairline];
    bar->_back = back;
    bar->_title = label;
    bar->_hairline = hairline;
    return bar;
}

- (void)backTapped {
    if (self.onBack) {
        self.onBack();
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.bounds.size.width;
    _hairline.frame = CGRectMake(0, 48, width, 1);
    if (_showsBack) {
        _back.frame = CGRectMake(4, 2, 44, 44);
        _title.frame = CGRectMake(48, 0, MAX(width - 48 - 16, 0), 48);
    } else {
        _title.frame = CGRectMake(16, 0, MAX(width - 32, 0), 48);
    }
}

@end

UIColor *DemoPageColor(void) {
    return [UIColor colorWithRed:0xF3 / 255.0 green:0xEF / 255.0 blue:0xE7 / 255.0 alpha:1];
}

@implementation DemoRoutes

+ (NSDictionary<NSString *, NSString *> *)titles {
    return @{
        @"stack": @"城南",
        @"market": @"南市",
        @"permission": @"权限",
        @"weather": @"天气",
        @"column": @"Column",
        @"row": @"Row",
        @"text": @"Text",
        @"image": @"Image",
        @"spacer": @"Spacer",
        @"list": @"List",
        @"progress": @"Progress",
        @"lottie": @"Lottie",
        @"input": @"Input",
        @"checkbox": @"CheckBox",
        @"radio": @"Radio",
        @"switch": @"Switch",
        @"inbox": @"收件",
        @"journey": @"行程",
        @"player": @"播放",
        @"chat": @"聊天",
        @"glass": @"液态玻璃"
    };
}

+ (NSString *)titleForPage:(NSString *)page {
    return [self titles][page] ?: page;
}

+ (NSDictionary<NSString *, NSArray<NSString *> *> *)components {
    return @{
        @"column": @[@"templates/column/column.json", @"templates/column/mock-data/column.json"],
        @"row": @[@"templates/row/row.json", @"templates/row/mock-data/row.json"],
        @"text": @[@"templates/text/text.json", @"templates/text/mock-data/text.json"],
        @"image": @[@"templates/image/image.json", @"templates/image/mock-data/image.json"],
        @"spacer": @[@"templates/spacer/spacer.json", @"templates/spacer/mock-data/spacer.json"],
        @"list": @[@"templates/list/list.json", @"templates/list/mock-data/list.json"],
        @"progress": @[@"templates/progress/progress.json", @"templates/progress/mock-data/progress.json"],
        @"lottie": @[@"templates/lottie/lottie.json", @"templates/lottie/mock-data/lottie.json"],
        @"input": @[@"templates/input/input.json", @"templates/input/mock-data/input.json"],
        @"checkbox": @[@"templates/checkbox/checkbox.json", @"templates/checkbox/mock-data/checkbox.json"],
        @"radio": @[@"templates/radio/radio.json", @"templates/radio/mock-data/radio.json"],
        @"switch": @[@"templates/switch/switch.json", @"templates/switch/mock-data/switch.json"],
        @"inbox": @[@"templates/inbox/inbox.json", @"templates/inbox/mock-data/inbox.json"],
        @"journey": @[@"templates/journey/journey.json", @"templates/journey/mock-data/journey.json"],
        @"player": @[@"templates/player/player.json", @"templates/player/mock-data/player.json"],
        @"chat": @[@"templates/chat/chat.json", @"templates/chat/mock-data/chat.json"],
        @"glass": @[@"templates/glass/glass.json", @"templates/glass/mock-data/glass.json"]
    };
}

+ (void)goBack:(UIViewController *)controller {
    PageStack *stack = [PageStack find:controller.view];
    if (stack && [stack pop:nil]) {
        return;
    }
    if (controller.navigationController.viewControllers.count > 1) {
        [controller.navigationController popViewControllerAnimated:YES];
    } else if (controller.presentingViewController) {
        [controller dismissViewControllerAnimated:YES completion:nil];
    }
}

+ (void)open:(UIViewController *)controller page:(NSString *)page {
    UIViewController *next = nil;
    if ([page isEqualToString:@"stack"]) {
        next = [[StackController alloc] initWithRoute:@"templates/stack/routes.json" bizId:@"demo" templateId:@"stack"];
    } else if ([page isEqualToString:@"market"]) {
        next = [MarketController new];
    } else if ([page isEqualToString:@"permission"]) {
        next = [PermissionController new];
    } else if ([page isEqualToString:@"weather"]) {
        next = [WeatherCardController new];
    } else {
        NSArray<NSString *> *spec = [self components][page];
        if (!spec) {
            [OTToast show:@"没有这个示例" inView:controller.view];
            return;
        }
        next = [[ComponentDemoController alloc] initWithTemplatePath:spec[0] dataPath:spec[1] title:[self titleForPage:page]];
    }
    if (controller.navigationController) {
        [controller.navigationController pushViewController:next animated:YES];
    } else {
        [controller presentViewController:next animated:YES completion:nil];
    }
}

@end
