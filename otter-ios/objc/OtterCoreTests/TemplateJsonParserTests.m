#import "TestSupport.h"
#import "TemplateJsonParser.h"
#import "TemplateKey.h"

@interface TemplateJsonParserTests : XCTestCase
@end

@implementation TemplateJsonParserTests

- (ParsedTemplate *)parse:(NSString *)json {
    NSError *error = nil;
    ParsedTemplate *parsed = [TemplateJsonParser parseJSON:json error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(parsed);
    return parsed;
}

- (void)testParsesSizeColorGradientAndEvents {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": {\n"
        @"    \"type\": \"column\",\n"
        @"    \"id\": \"root\",\n"
        @"    \"layout\": {\n"
        @"      \"width\": \"fill\",\n"
        @"      \"height\": \"wrap\",\n"
        @"      \"padding\": { \"start\": 8, \"top\": 4 },\n"
        @"      \"grow\": 1,\n"
        @"      \"justify\": \"spaceBetween\",\n"
        @"      \"align\": \"start\"\n"
        @"    },\n"
        @"    \"style\": {\n"
        @"      \"background\": { \"direction\": \"bottom\", \"colors\": [\"#112233\", \"#ffffff\"] },\n"
        @"      \"radius\": { \"topStart\": 12 },\n"
        @"      \"border\": { \"color\": \"#ff0000\", \"width\": 1 }\n"
        @"    },\n"
        @"    \"children\": [\n"
        @"      {\n"
        @"        \"type\": \"text\",\n"
        @"        \"id\": \"title\",\n"
        @"        \"text\": \"$title\",\n"
        @"        \"layout\": { \"width\": 100, \"height\": 20 },\n"
        @"        \"style\": { \"color\": \"transparent\", \"fontSize\": 16, \"align\": \"center\" },\n"
        @"        \"onClick\": [\"rename\"]\n"
        @"      }\n"
        @"    ]\n"
        @"  },\n"
        @"  \"events\": {\n"
        @"    \"rename\": { \"action\": \"setText\", \"target\": \"title\", \"value\": \"已改\" }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    ParsedNode *root = parsed.root;
    XCTAssertEqualObjects([TemplateKey COLUMN], root.viewName);
    expect(root.attrs[[TemplateKey ATTR_WIDTH]], @"match_parent");
    expect(root.attrs[[TemplateKey ATTR_HEIGHT]], @"wrap_content");
    expect(root.attrs[[TemplateKey ATTR_PADDING_START]], @"8");
    expect(root.attrs[[TemplateKey ATTR_PADDING_TOP]], @"4");
    expect(root.attrs[[TemplateKey ATTR_FLEX_GROW]], @"1");
    expect(root.attrs[[TemplateKey FLEXBOX_ATTR_JUSTIFY_CONTENT]], @"space-between");
    expect(root.attrs[[TemplateKey FLEXBOX_ATTR_ALIGN_ITEMS]], @"start");
    expect(root.attrs[[TemplateKey ATTR_BACKGROUND]], @"linear-gradient(to bottom, #112233, #ffffff)");
    expect(root.attrs[[TemplateKey ATTR_LEFT_TOP_RADIUS]], @"12");
    XCTAssertEqual(1, (NSInteger)root.children.count);
    XCTAssertEqualObjects([TemplateKey TEXT], root.children[0].viewName);
    expect(root.children[0].attrs[[TemplateKey ATTR_ONCLICK]], @"rename");
    expect([[parsed.events[@"rename"] getJSONObject:@"params"] getString:@"id"], @"title");
}

- (void)testListItemIsSeparateAndLottieGetsDefaults {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": {\n"
        @"    \"type\": \"list\",\n"
        @"    \"id\": \"feed\",\n"
        @"    \"data\": \"$items\",\n"
        @"    \"layout\": { \"width\": \"fill\", \"height\": 120 },\n"
        @"    \"item\": {\n"
        @"      \"type\": \"lottie\",\n"
        @"      \"src\": \"assets:animation/lottie-sunny\",\n"
        @"      \"layout\": { \"width\": 24, \"height\": 24 }\n"
        @"    }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    XCTAssertEqualObjects([TemplateKey OT_LIST], parsed.root.viewName);
    XCTAssertEqual(0, (NSInteger)parsed.root.children.count);
    expect(parsed.root.attrs[[TemplateKey ATTR_LIST_DIRECTION]], @"vertical");
    ParsedNode *item = parsed.root.item;
    XCTAssertNotNil(item);
    XCTAssertEqualObjects([TemplateKey ANIMATION], item.viewName);
    expect(item.attrs[[TemplateKey ATTR_ANI_REPEAT_COUNT]], @"infinite");
    expect(item.attrs[[TemplateKey ATTR_ANI_REPEAT_MODE]], @"restart");
    expect(item.attrs[[TemplateKey ATTR_ANI_AUTO_PLAY]], @"true");
    XCTAssertNil(parsed.root.item.children.firstObject);
}

- (void)testProgressTrackAndBarUseEngineColorFields {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": {\n"
        @"    \"type\": \"progress\",\n"
        @"    \"layout\": { \"width\": 80, \"height\": 7 },\n"
        @"    \"from\": \"$start\",\n"
        @"    \"to\": 0.8,\n"
        @"    \"animate\": false,\n"
        @"    \"style\": { \"track\": \"$strokeColor\", \"bar\": \"#FFD700\" }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    expect(parsed.root.attrs[[TemplateKey ATTR_STROKE_COLOR]], @"$strokeColor");
    expect(parsed.root.attrs[[TemplateKey ATTR_TRAIL_COLOR]], @"#FFD700");
    expect(parsed.root.attrs[[TemplateKey ATTR_VALUE_MIN]], @"$start");
    expect(parsed.root.attrs[[TemplateKey ATTR_VALUE_MAX]], @"0.8");
    expect(parsed.root.attrs[[TemplateKey ATTR_ANIMATE_ENABLE]], @"false");
}

- (void)testProgressBarAcceptsGradient {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": {\n"
        @"    \"type\": \"progress\",\n"
        @"    \"layout\": { \"width\": 80, \"height\": 7 },\n"
        @"    \"from\": 0,\n"
        @"    \"to\": 0.5,\n"
        @"    \"style\": {\n"
        @"      \"track\": \"#245566\",\n"
        @"      \"bar\": { \"direction\": \"right\", \"colors\": [\"#7EB6C9\", \"#F2C14E\", \"#E07A3D\"] }\n"
        @"    }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    expect(parsed.root.attrs[[TemplateKey ATTR_STROKE_COLOR]], @"#245566");
    expect(parsed.root.attrs[[TemplateKey ATTR_TRAIL_COLOR]], @"linear-gradient(to right, #7EB6C9, #F2C14E, #E07A3D)");
}

- (void)testRejectsUnknownFieldMissingEventAndMissingTarget {
    assertFails(@"$.layout.children 不是这里能写的字段", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"text\", \"text\": \"Hi\", \"layout\": {\"width\": 1, \"height\": 1}, \"children\": []}}" error:error];
    });
    assertFails(@"onClick 引用了不存在的事件 missing", ^(NSError **error) {
        [TemplateJsonParser parseJSON:
            @"{\n"
            @"  \"layout\": {\n"
            @"    \"type\": \"text\",\n"
            @"    \"id\": \"label\",\n"
            @"    \"text\": \"Hi\",\n"
            @"    \"layout\": { \"width\": 1, \"height\": 1 },\n"
            @"    \"onClick\": [\"missing\"]\n"
            @"  }\n"
            @"}"
            error:error];
    });
    assertFails(@"事件 rename 的 target「gone」在模版中不存在", ^(NSError **error) {
        [TemplateJsonParser parseJSON:
            @"{\n"
            @"  \"layout\": {\n"
            @"    \"type\": \"text\",\n"
            @"    \"id\": \"label\",\n"
            @"    \"text\": \"Hi\",\n"
            @"    \"layout\": { \"width\": 1, \"height\": 1 }\n"
            @"  },\n"
            @"  \"events\": {\n"
            @"    \"rename\": { \"action\": \"setText\", \"target\": \"gone\", \"value\": \"x\" }\n"
            @"  }\n"
            @"}"
            error:error];
    });
}

- (void)testBackEventClosesThePage {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": {\n"
        @"    \"type\": \"text\",\n"
        @"    \"text\": \"返回\",\n"
        @"    \"layout\": { \"width\": 40, \"height\": 20 },\n"
        @"    \"onClick\": [\"goBack\"]\n"
        @"  },\n"
        @"  \"events\": {\n"
        @"    \"goBack\": { \"action\": \"back\" }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    JSONObject *params = [parsed.events[@"goBack"] getJSONObject:@"params"];
    XCTAssertNotNil(params);
    expect([params getString:@"fun"], @"back");
}

- (void)testParsesInputWithAllFields {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": {\n"
        @"    \"type\": \"input\",\n"
        @"    \"id\": \"name\",\n"
        @"    \"value\": \"$name\",\n"
        @"    \"hint\": \"请输入\",\n"
        @"    \"keyboard\": \"email\",\n"
        @"    \"maxLength\": 20,\n"
        @"    \"lines\": 3,\n"
        @"    \"layout\": { \"width\": \"fill\", \"height\": 44 },\n"
        @"    \"style\": {\n"
        @"      \"color\": \"#1F1A17\",\n"
        @"      \"fontSize\": 16,\n"
        @"      \"align\": \"start\",\n"
        @"      \"hintColor\": \"#8A8178\",\n"
        @"      \"background\": \"#FFFCF8\",\n"
        @"      \"radius\": 12\n"
        @"    }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    ParsedNode *input = parsed.root;
    XCTAssertEqualObjects([TemplateKey INPUT], input.viewName);
    expect(input.attrs[[TemplateKey ATTR_TEXT]], @"$name");
    expect(input.attrs[[TemplateKey ATTR_HINT]], @"请输入");
    expect(input.attrs[[TemplateKey ATTR_INPUT_TYPE]], @"email");
    expect(input.attrs[[TemplateKey ATTR_MAX_LENGTH]], @"20");
    expect(input.attrs[[TemplateKey ATTR_LINES]], @"3");
    expect(input.attrs[[TemplateKey ATTR_TEXT_COLOR]], @"#1F1A17");
    expect(input.attrs[[TemplateKey ATTR_TEXT_SIZE]], @"16");
    expect(input.attrs[[TemplateKey ATTR_TEXT_ALIGN]], @"start");
    expect(input.attrs[[TemplateKey ATTR_HINT_COLOR]], @"#8A8178");
    expect(input.attrs[[TemplateKey ATTR_BACKGROUND]], @"#FFFCF8");
    expect(input.attrs[[TemplateKey ATTR_RADIUS]], @"12");
    expect(input.attrs[[TemplateKey ATTR_WIDTH]], @"match_parent");
}

- (void)testInputOmitsOptionalFieldsAndDefaultsKeyboardToText {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": {\n"
        @"    \"type\": \"input\",\n"
        @"    \"layout\": { \"width\": \"fill\", \"height\": 44 }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    ParsedNode *input = parsed.root;
    XCTAssertEqualObjects([TemplateKey INPUT], input.viewName);
    XCTAssertNil(input.attrs[[TemplateKey ATTR_TEXT]]);
    XCTAssertNil(input.attrs[[TemplateKey ATTR_HINT]]);
    XCTAssertNil(input.attrs[[TemplateKey ATTR_MAX_LENGTH]]);
    expect(input.attrs[[TemplateKey ATTR_INPUT_TYPE]], @"text");
    XCTAssertNil(input.attrs[[TemplateKey ATTR_LINES]]);
}

- (void)testParsesCheckBoxLabelTintAndTextStyle {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": {\n"
        @"    \"type\": \"checkbox\",\n"
        @"    \"id\": \"agree\",\n"
        @"    \"checked\": true,\n"
        @"    \"label\": \"$同意\",\n"
        @"    \"layout\": { \"width\": \"fill\", \"height\": 44 },\n"
        @"    \"style\": { \"color\": \"#1F1A17\", \"fontSize\": 14, \"tint\": \"#1F6F6A\" }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    ParsedNode *box = parsed.root;
    XCTAssertEqualObjects([TemplateKey CHECKBOX], box.viewName);
    expect(box.attrs[[TemplateKey ATTR_CHECKED]], @"true");
    expect(box.attrs[[TemplateKey ATTR_TEXT]], @"$同意");
    expect(box.attrs[[TemplateKey ATTR_TINT]], @"#1F6F6A");
    expect(box.attrs[[TemplateKey ATTR_TEXT_COLOR]], @"#1F1A17");
    expect(box.attrs[[TemplateKey ATTR_TEXT_SIZE]], @"14");
}

- (void)testCheckBoxDefaultsUncheckedAndOmitsLabel {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": {\n"
        @"    \"type\": \"checkbox\",\n"
        @"    \"layout\": { \"width\": \"fill\", \"height\": 44 }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    XCTAssertEqualObjects([TemplateKey CHECKBOX], parsed.root.viewName);
    expect(parsed.root.attrs[[TemplateKey ATTR_CHECKED]], @"false");
    XCTAssertNil(parsed.root.attrs[[TemplateKey ATTR_TEXT]]);
}

- (void)testCheckBoxKeepsCheckedExpression {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": {\n"
        @"    \"type\": \"checkbox\",\n"
        @"    \"checked\": \"$done\",\n"
        @"    \"layout\": { \"width\": \"fill\", \"height\": 44 }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    expect(parsed.root.attrs[[TemplateKey ATTR_CHECKED]], @"$done");
}

- (void)testRejectsInvalidInputAndCheckBoxFields {
    assertFails(@"$.layout.keyboard 只能是 text、number、password、email、phone", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"input\", \"keyboard\": \"url\", \"layout\": {\"width\": 1, \"height\": 1}}}" error:error];
    });
    assertFails(@"$.layout.maxLength 只能是非负整数", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"input\", \"maxLength\": 1.5, \"layout\": {\"width\": 1, \"height\": 1}}}" error:error];
    });
    assertFails(@"$.layout.maxLength 不能是负数", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"input\", \"maxLength\": -1, \"layout\": {\"width\": 1, \"height\": 1}}}" error:error];
    });
    assertFails(@"$.layout.checked 必须是布尔值或以 $ 开头", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"checkbox\", \"checked\": \"yes\", \"layout\": {\"width\": 1, \"height\": 1}}}" error:error];
    });
    assertFails(@"$.layout.children 不是这里能写的字段", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"input\", \"layout\": {\"width\": 1, \"height\": 1}, \"children\": []}}" error:error];
    });
    assertFails(@"$.layout.style.align 不是这里能写的字段", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"checkbox\", \"layout\": {\"width\": 1, \"height\": 1}, \"style\": {\"align\": \"start\"}}}" error:error];
    });
}

- (void)testSetCheckedEventChangesAttributes {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": {\n"
        @"    \"type\": \"checkbox\",\n"
        @"    \"id\": \"agree\",\n"
        @"    \"layout\": { \"width\": \"fill\", \"height\": 44 }\n"
        @"  },\n"
        @"  \"events\": {\n"
        @"    \"mark\": { \"action\": \"setChecked\", \"target\": \"agree\", \"value\": false }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    JSONObject *event = parsed.events[@"mark"];
    XCTAssertNotNil(event);
    expect([event getString:@"class"], @"view");
    JSONObject *params = [event getJSONObject:@"params"];
    XCTAssertNotNil(params);
    expect([params getString:@"fun"], @"changeAttributes");
    expect([params getString:@"key"], @"setChecked");
    expect([params getString:@"id"], @"agree");
    expect([params getString:@"value"], @"false");
}

- (void)testSetCheckedEventKeepsExpressionValue {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": {\n"
        @"    \"type\": \"checkbox\",\n"
        @"    \"id\": \"agree\",\n"
        @"    \"layout\": { \"width\": \"fill\", \"height\": 44 }\n"
        @"  },\n"
        @"  \"events\": {\n"
        @"    \"mark\": { \"action\": \"setChecked\", \"target\": \"agree\", \"value\": \"$done\" }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    JSONObject *params = [parsed.events[@"mark"] getJSONObject:@"params"];
    XCTAssertNotNil(params);
    expect([params getString:@"value"], @"$done");
}

- (void)testAppendEventCopiesItemAndTargets {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": {\n"
        @"    \"type\": \"column\",\n"
        @"    \"layout\": { \"width\": \"fill\", \"height\": \"fill\" },\n"
        @"    \"children\": [\n"
        @"      {\n"
        @"        \"type\": \"list\",\n"
        @"        \"id\": \"chat_list\",\n"
        @"        \"data\": \"$messages\",\n"
        @"        \"layout\": { \"width\": \"fill\", \"height\": 100 },\n"
        @"        \"item\": {\n"
        @"          \"type\": \"text\",\n"
        @"          \"text\": \"$body\",\n"
        @"          \"layout\": { \"width\": \"fill\", \"height\": 20 }\n"
        @"        }\n"
        @"      },\n"
        @"      {\n"
        @"        \"type\": \"input\",\n"
        @"        \"id\": \"composer\",\n"
        @"        \"layout\": { \"width\": \"fill\", \"height\": 44 }\n"
        @"      }\n"
        @"    ]\n"
        @"  },\n"
        @"  \"events\": {\n"
        @"    \"sendMessage\": {\n"
        @"      \"action\": \"append\",\n"
        @"      \"list\": \"chat_list\",\n"
        @"      \"from\": \"composer\",\n"
        @"      \"field\": \"body\",\n"
        @"      \"data\": \"messages\",\n"
        @"      \"empty\": \"先写一句\",\n"
        @"      \"item\": { \"name\": \"我\", \"side\": \"end\" }\n"
        @"    }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    JSONObject *event = parsed.events[@"sendMessage"];
    XCTAssertNotNil(event);
    expect([event getString:@"class"], @"list");
    JSONObject *params = [event getJSONObject:@"params"];
    XCTAssertNotNil(params);
    expect([params getString:@"fun"], @"append");
    expect([params getString:@"id"], @"chat_list");
    expect([params getString:@"from"], @"composer");
    expect([params getString:@"field"], @"body");
    expect([params getString:@"data"], @"messages");
    expect([params getString:@"empty"], @"先写一句");
    JSONObject *item = [params getJSONObject:@"item"];
    XCTAssertNotNil(item);
    expect([item getString:@"name"], @"我");
    expect([item getString:@"side"], @"end");
}

- (void)testRejectsUnrecognizedEventAction {
    assertFails(@"$.events.bad.action「nope」无法识别，事件 bad 只能是 toast、setText、setTextStyle、setChecked、append、update、remove、open、back、replace、popTo、host", ^(NSError **error) {
        [TemplateJsonParser parseJSON:
            @"{\n"
            @"  \"layout\": {\n"
            @"    \"type\": \"text\",\n"
            @"    \"text\": \"Hi\",\n"
            @"    \"layout\": { \"width\": 1, \"height\": 1 }\n"
            @"  },\n"
            @"  \"events\": {\n"
            @"    \"bad\": { \"action\": \"nope\" }\n"
            @"  }\n"
            @"}"
            error:error];
    });
}

- (void)testParsesRadioGroupLabelAndTint {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": {\n"
        @"    \"type\": \"radio\",\n"
        @"    \"id\": \"medium\",\n"
        @"    \"group\": \"size\",\n"
        @"    \"checked\": true,\n"
        @"    \"label\": \"$中杯\",\n"
        @"    \"layout\": { \"width\": \"fill\", \"height\": 48 },\n"
        @"    \"style\": { \"color\": \"#1F1A17\", \"fontSize\": 15, \"tint\": \"#1F6F6A\" }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    XCTAssertEqualObjects([TemplateKey RADIO], parsed.root.viewName);
    expect(parsed.root.attrs[[TemplateKey ATTR_GROUP]], @"size");
    expect(parsed.root.attrs[[TemplateKey ATTR_CHECKED]], @"true");
    expect(parsed.root.attrs[[TemplateKey ATTR_TEXT]], @"$中杯");
    expect(parsed.root.attrs[[TemplateKey ATTR_TINT]], @"#1F6F6A");
    expect(parsed.root.attrs[[TemplateKey ATTR_TEXT_COLOR]], @"#1F1A17");
    expect(parsed.root.attrs[[TemplateKey ATTR_TEXT_SIZE]], @"15");
    expect(parsed.root.attrs[[TemplateKey ATTR_WIDTH]], @"match_parent");
}

- (void)testRadioKeepsGroupExpressionAndDefaultsUnchecked {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": {\n"
        @"    \"type\": \"radio\",\n"
        @"    \"group\": \"$bundle\",\n"
        @"    \"layout\": { \"width\": \"fill\", \"height\": 48 }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    expect(parsed.root.attrs[[TemplateKey ATTR_GROUP]], @"$bundle");
    expect(parsed.root.attrs[[TemplateKey ATTR_CHECKED]], @"false");
    XCTAssertNil(parsed.root.attrs[[TemplateKey ATTR_TEXT]]);
}

- (void)testRejectsInvalidRadioFields {
    assertFails(@"$.layout 缺少 group", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"radio\", \"layout\": {\"width\": 1, \"height\": 1}}}" error:error];
    });
    assertFails(@"$.layout.group「1cup」必须是字母或下划线开头的标识符，或以 $ 开头", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"radio\", \"group\": \"1cup\", \"layout\": {\"width\": 1, \"height\": 1}}}" error:error];
    });
    assertFails(@"$.layout.checked 必须是布尔值或以 $ 开头", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"radio\", \"group\": \"size\", \"checked\": \"yes\", \"layout\": {\"width\": 1, \"height\": 1}}}" error:error];
    });
    assertFails(@"$.layout.style.align 不是这里能写的字段", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"radio\", \"group\": \"size\", \"layout\": {\"width\": 1, \"height\": 1}, \"style\": {\"align\": \"center\"}}}" error:error];
    });
}

- (void)testParsesSwitchLabelTintAndTextStyle {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": {\n"
        @"    \"type\": \"switch\",\n"
        @"    \"id\": \"wifi\",\n"
        @"    \"checked\": true,\n"
        @"    \"label\": \"$无线\",\n"
        @"    \"layout\": { \"width\": \"fill\", \"height\": 48 },\n"
        @"    \"style\": { \"color\": \"#1F1A17\", \"fontSize\": 16, \"tint\": \"#C45C26\" }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    XCTAssertEqualObjects([TemplateKey SWITCH], parsed.root.viewName);
    expect(parsed.root.attrs[[TemplateKey ATTR_CHECKED]], @"true");
    expect(parsed.root.attrs[[TemplateKey ATTR_TEXT]], @"$无线");
    expect(parsed.root.attrs[[TemplateKey ATTR_TINT]], @"#C45C26");
    expect(parsed.root.attrs[[TemplateKey ATTR_TEXT_COLOR]], @"#1F1A17");
    expect(parsed.root.attrs[[TemplateKey ATTR_TEXT_SIZE]], @"16");
}

- (void)testSwitchDefaultsOffAndOmitsLabel {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": {\n"
        @"    \"type\": \"switch\",\n"
        @"    \"checked\": \"$wifi\",\n"
        @"    \"layout\": { \"width\": \"fill\", \"height\": 48 }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    expect(parsed.root.attrs[[TemplateKey ATTR_CHECKED]], @"$wifi");
    XCTAssertNil(parsed.root.attrs[[TemplateKey ATTR_TEXT]]);
    XCTAssertNil(parsed.root.attrs[[TemplateKey ATTR_GROUP]]);
}

- (void)testOpenWithoutParamsKeepsPageAndOmitsInnerParams {
    ParsedTemplate *literal = [self parse:
        @"{\n"
        @"  \"layout\": { \"type\": \"text\", \"text\": \"Hi\", \"layout\": { \"width\": 1, \"height\": 1 } },\n"
        @"  \"events\": { \"openPage\": { \"action\": \"open\", \"page\": \"detail\" } }\n"
        @"}"];
    if (literal == nil) return;
    JSONObject *literalEvent = literal.events[@"openPage"];
    XCTAssertNotNil(literalEvent);
    expect([literalEvent getString:@"class"], @"nav");
    XCTAssertEqual(2, literalEvent.size);
    JSONObject *literalParams = [literalEvent getJSONObject:@"params"];
    XCTAssertNotNil(literalParams);
    expect([literalParams getString:@"fun"], @"open");
    expect([literalParams getString:@"page"], @"detail");
    XCTAssertEqual(2, literalParams.size);
    XCTAssertTrue(![literalParams containsKey:@"params"]);

    ParsedTemplate *expression = [self parse:
        @"{\n"
        @"  \"layout\": { \"type\": \"text\", \"text\": \"Hi\", \"layout\": { \"width\": 1, \"height\": 1 } },\n"
        @"  \"events\": { \"openPage\": { \"action\": \"open\", \"page\": \"$page\" } }\n"
        @"}"];
    if (expression == nil) return;
    JSONObject *expressionEvent = expression.events[@"openPage"];
    XCTAssertNotNil(expressionEvent);
    expect([expressionEvent getString:@"class"], @"nav");
    JSONObject *expressionParams = [expressionEvent getJSONObject:@"params"];
    XCTAssertNotNil(expressionParams);
    expect([expressionParams getString:@"fun"], @"open");
    expect([expressionParams getString:@"page"], @"$page");
    XCTAssertEqual(2, expressionParams.size);
    XCTAssertTrue(![expressionParams containsKey:@"params"]);
}

- (void)testOpenParamsKeepStringNumberAndBoolean {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": { \"type\": \"text\", \"text\": \"Hi\", \"layout\": { \"width\": 1, \"height\": 1 } },\n"
        @"  \"events\": {\n"
        @"    \"openPage\": {\n"
        @"      \"action\": \"open\",\n"
        @"      \"page\": \"detail\",\n"
        @"      \"params\": {\n"
        @"        \"city\": \"$city\",\n"
        @"        \"title\": \"北京\",\n"
        @"        \"count\": 2,\n"
        @"        \"ratio\": 2.5,\n"
        @"        \"delta\": -1,\n"
        @"        \"ok\": true\n"
        @"      }\n"
        @"    }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    JSONObject *event = parsed.events[@"openPage"];
    XCTAssertNotNil(event);
    expect([event getString:@"class"], @"nav");
    JSONObject *params = [event getJSONObject:@"params"];
    XCTAssertNotNil(params);
    expect([params getString:@"fun"], @"open");
    expect([params getString:@"page"], @"detail");
    JSONObject *inner = [params getJSONObject:@"params"];
    XCTAssertNotNil(inner);
    expectValue([inner get:@"city"], [JSONValue string:@"$city"]);
    expectValue([inner get:@"title"], [JSONValue string:@"北京"]);
    assertNumberInt([inner get:@"count"], 2);
    assertNumberDouble([inner get:@"ratio"], 2.5);
    assertNumberInt([inner get:@"delta"], -1);
    expectValue([inner get:@"ok"], [JSONValue bool:YES]);
}

- (void)testOpenEmptyParamsBecomesEmptyObject {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": { \"type\": \"text\", \"text\": \"Hi\", \"layout\": { \"width\": 1, \"height\": 1 } },\n"
        @"  \"events\": { \"openPage\": { \"action\": \"open\", \"page\": \"detail\", \"params\": {} } }\n"
        @"}"];
    if (parsed == nil) return;
    JSONObject *params = [parsed.events[@"openPage"] getJSONObject:@"params"];
    XCTAssertNotNil(params);
    expect([params getString:@"fun"], @"open");
    expect([params getString:@"page"], @"detail");
    JSONObject *inner = [params getJSONObject:@"params"];
    XCTAssertNotNil(inner);
    XCTAssertEqual(0, inner.size);
}

- (void)testOpenParamsKeepNestedObjectAndArray {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": { \"type\": \"text\", \"text\": \"Hi\", \"layout\": { \"width\": 1, \"height\": 1 } },\n"
        @"  \"events\": {\n"
        @"    \"openPage\": {\n"
        @"      \"action\": \"open\",\n"
        @"      \"page\": \"detail\",\n"
        @"      \"params\": {\n"
        @"        \"city\": { \"name\": \"上海\" },\n"
        @"        \"tags\": [\"$tag\", 1]\n"
        @"      }\n"
        @"    }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    JSONObject *params = [[parsed.events[@"openPage"] getJSONObject:@"params"] getJSONObject:@"params"];
    XCTAssertNotNil(params);
    expect([[params getJSONObject:@"city"] getString:@"name"], @"上海");
    JSONArray *tags = [params getJSONArray:@"tags"];
    XCTAssertNotNil(tags);
    expect([tags getString:0], @"$tag");
    assertNumberInt([tags get:1], 1);
}

- (void)testRejectsInvalidOpenParamsAndPage {
    assertFails(@"$.events.openPage.params 必须是对象", ^(NSError **error) {
        [TemplateJsonParser parseJSON:
            @"{\n"
            @"  \"layout\": { \"type\": \"text\", \"text\": \"Hi\", \"layout\": { \"width\": 1, \"height\": 1 } },\n"
            @"  \"events\": { \"openPage\": { \"action\": \"open\", \"page\": \"detail\", \"params\": [] } }\n"
            @"}"
            error:error];
    });
    assertFails(@"$.events.openPage.params.city 必须是字符串、数字、布尔、对象或数组", ^(NSError **error) {
        [TemplateJsonParser parseJSON:
            @"{\n"
            @"  \"layout\": { \"type\": \"text\", \"text\": \"Hi\", \"layout\": { \"width\": 1, \"height\": 1 } },\n"
            @"  \"events\": {\n"
            @"    \"openPage\": { \"action\": \"open\", \"page\": \"detail\", \"params\": { \"city\": null } }\n"
            @"  }\n"
            @"}"
            error:error];
    });
    assertFails(@"$.events.openPage.params.1city 不是这里能写的字段", ^(NSError **error) {
        [TemplateJsonParser parseJSON:
            @"{\n"
            @"  \"layout\": { \"type\": \"text\", \"text\": \"Hi\", \"layout\": { \"width\": 1, \"height\": 1 } },\n"
            @"  \"events\": {\n"
            @"    \"openPage\": { \"action\": \"open\", \"page\": \"detail\", \"params\": { \"1city\": \"上海\" } }\n"
            @"  }\n"
            @"}"
            error:error];
    });
    assertFails(@"$.events.openPage.page 必须是页面名或以 $ 开头", ^(NSError **error) {
        [TemplateJsonParser parseJSON:
            @"{\n"
            @"  \"layout\": { \"type\": \"text\", \"text\": \"Hi\", \"layout\": { \"width\": 1, \"height\": 1 } },\n"
            @"  \"events\": { \"openPage\": { \"action\": \"open\", \"page\": \"1ab\" } }\n"
            @"}"
            error:error];
    });
    assertFails(@"$.events.openPage.target 不是这里能写的字段", ^(NSError **error) {
        [TemplateJsonParser parseJSON:
            @"{\n"
            @"  \"layout\": { \"type\": \"text\", \"text\": \"Hi\", \"layout\": { \"width\": 1, \"height\": 1 } },\n"
            @"  \"events\": { \"openPage\": { \"action\": \"open\", \"page\": \"detail\", \"target\": \"title\" } }\n"
            @"}"
            error:error];
    });
}

- (void)testBackRejectsExtraFields {
    assertFails(@"$.events.goBack.note 不是这里能写的字段", ^(NSError **error) {
        [TemplateJsonParser parseJSON:
            @"{\n"
            @"  \"layout\": { \"type\": \"text\", \"text\": \"Hi\", \"layout\": { \"width\": 1, \"height\": 1 } },\n"
            @"  \"events\": { \"goBack\": { \"action\": \"back\", \"note\": \"bye\" } }\n"
            @"}"
            error:error];
    });
}

- (void)testBackParamsKeepTheSameValuesAsOpen {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": { \"type\": \"text\", \"text\": \"Hi\", \"layout\": { \"width\": 1, \"height\": 1 } },\n"
        @"  \"events\": {\n"
        @"    \"goBack\": {\n"
        @"      \"action\": \"back\",\n"
        @"      \"params\": { \"memos\": \"$lines\", \"count\": 1, \"ok\": false }\n"
        @"    }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    JSONObject *params = [parsed.events[@"goBack"] getJSONObject:@"params"];
    XCTAssertNotNil(params);
    expect([params getString:@"fun"], @"back");
    JSONObject *inner = [params getJSONObject:@"params"];
    XCTAssertNotNil(inner);
    expect([inner getString:@"memos"], @"$lines");
    assertNumberInt([inner get:@"count"], 1);
    expectValue([inner get:@"ok"], [JSONValue bool:NO]);
}

- (void)testParsesGlassOnContainersAndFillsDefaults {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": {\n"
        @"    \"type\": \"column\",\n"
        @"    \"layout\": { \"width\": \"fill\", \"height\": \"wrap\" },\n"
        @"    \"style\": { \"glass\": {}, \"radius\": 16 },\n"
        @"    \"children\": [\n"
        @"      {\n"
        @"        \"type\": \"row\",\n"
        @"        \"layout\": { \"width\": \"fill\", \"height\": 36 },\n"
        @"        \"style\": { \"glass\": { \"style\": \"clear\", \"tint\": \"$accent\", \"interactive\": true } }\n"
        @"      },\n"
        @"      {\n"
        @"        \"type\": \"spacer\",\n"
        @"        \"layout\": { \"width\": \"fill\", \"height\": 8 },\n"
        @"        \"style\": {\n"
        @"          \"glass\": { \"tint\": \"#80FFFFFF\" },\n"
        @"          \"border\": { \"color\": \"#66FFFFFF\", \"width\": 0.5 }\n"
        @"        }\n"
        @"      },\n"
        @"      {\n"
        @"        \"type\": \"list\",\n"
        @"        \"id\": \"feed\",\n"
        @"        \"data\": \"$items\",\n"
        @"        \"layout\": { \"width\": \"fill\", \"height\": 80 },\n"
        @"        \"item\": {\n"
        @"          \"type\": \"column\",\n"
        @"          \"layout\": { \"width\": \"fill\", \"height\": \"wrap\" },\n"
        @"          \"style\": { \"glass\": { \"style\": \"clear\" } }\n"
        @"        }\n"
        @"      }\n"
        @"    ]\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    ParsedNode *root = parsed.root;
    expect(root.attrs[[TemplateKey ATTR_GLASS_STYLE]], @"regular");
    XCTAssertNil(root.attrs[[TemplateKey ATTR_GLASS_TINT]]);
    XCTAssertNil(root.attrs[[TemplateKey ATTR_GLASS_INTERACTIVE]]);
    XCTAssertNil(root.attrs[[TemplateKey ATTR_BACKGROUND]]);
    expect(root.attrs[[TemplateKey ATTR_RADIUS]], @"16");
    ParsedNode *row = root.children[0];
    expect(row.attrs[[TemplateKey ATTR_GLASS_STYLE]], @"clear");
    expect(row.attrs[[TemplateKey ATTR_GLASS_TINT]], @"$accent");
    expect(row.attrs[[TemplateKey ATTR_GLASS_INTERACTIVE]], @"true");
    ParsedNode *spacer = root.children[1];
    expect(spacer.attrs[[TemplateKey ATTR_GLASS_STYLE]], @"regular");
    expect(spacer.attrs[[TemplateKey ATTR_GLASS_TINT]], @"#80FFFFFF");
    XCTAssertNil(spacer.attrs[[TemplateKey ATTR_GLASS_INTERACTIVE]]);
    expect(spacer.attrs[[TemplateKey ATTR_BORDER_COLOR]], @"#66FFFFFF");
    expect(spacer.attrs[[TemplateKey ATTR_BORDER_WIDTH]], @"0.5");
    XCTAssertNil(root.children[2].attrs[[TemplateKey ATTR_GLASS_STYLE]]);
    ParsedNode *item = root.children[2].item;
    XCTAssertNotNil(item);
    expect(item.attrs[[TemplateKey ATTR_GLASS_STYLE]], @"clear");
    XCTAssertNil(item.attrs[[TemplateKey ATTR_GLASS_TINT]]);
}

- (void)testRejectsGlassOnTheWrongNodeOrWithBackground {
    assertFails(@"$.layout.style.glass 不是这里能写的字段", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"text\", \"text\": \"Hi\", \"layout\": {\"width\": 1, \"height\": 1}, \"style\": {\"glass\": {}}}}" error:error];
    });
    assertFails(@"$.layout.style 不能同时写 background 和 glass", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"column\", \"layout\": {\"width\": 1, \"height\": 1}, \"style\": {\"background\": \"red\", \"glass\": {}}}}" error:error];
    });
    assertFails(@"$.layout.style.glass 必须是对象", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"column\", \"layout\": {\"width\": 1, \"height\": 1}, \"style\": {\"glass\": 1}}}" error:error];
    });
    assertFails(@"$.layout.style.glass.style 只能是 regular、clear", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"row\", \"layout\": {\"width\": 1, \"height\": 1}, \"style\": {\"glass\": {\"style\": \"heavy\"}}}}" error:error];
    });
    assertFails(@"$.layout.style.glass.style 必须是字符串", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"spacer\", \"layout\": {\"width\": 1, \"height\": 1}, \"style\": {\"glass\": {\"style\": 1}}}}" error:error];
    });
    assertFails(@"$.layout.style.glass.blur 不是这里能写的字段", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"column\", \"layout\": {\"width\": 1, \"height\": 1}, \"style\": {\"glass\": {\"blur\": 12}}}}" error:error];
    });
    assertFails(@"$.layout.style.glass.tint 必须是 #RGB、#RRGGBB、#AARRGGBB、transparent，或以 $ 开头", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"column\", \"layout\": {\"width\": 1, \"height\": 1}, \"style\": {\"glass\": {\"tint\": \"white\"}}}}" error:error];
    });
    assertFails(@"$.layout.style.glass.tint 必须是颜色，不能是渐变", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"column\", \"layout\": {\"width\": 1, \"height\": 1}, \"style\": {\"glass\": {\"tint\": {\"direction\": \"bottom\", \"colors\": [\"#ffffff\", \"#000000\"]}}}}}" error:error];
    });
    assertFails(@"$.layout.style.glass.interactive 必须是布尔值", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"column\", \"layout\": {\"width\": 1, \"height\": 1}, \"style\": {\"glass\": {\"interactive\": \"yes\"}}}}" error:error];
    });
    assertFails(@"$.layout.style.glass.opacity 不是这里能写的字段", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"column\", \"layout\": {\"width\": 1, \"height\": 1}, \"style\": {\"glass\": {\"opacity\": 1}}}}" error:error];
    });
}

- (void)testDemoTemplatesParse {
    NSURL *root = OTFirstExistingDirectory(@[
        @"Demo/assets/templates",
    ]);
    XCTAssertNotNil(root, @"找不到 Demo 模版目录");
    if (root == nil) {
        return;
    }
    NSArray<NSString *> *relatives = @[
        @"home-demo/home.json",
        @"weather-card-demo/weather-card.json",
        @"column/column.json",
        @"row/row.json",
        @"text/text.json",
        @"image/image.json",
        @"spacer/spacer.json",
        @"list/list.json",
        @"progress/progress.json",
        @"lottie/lottie.json",
        @"input/input.json",
        @"checkbox/checkbox.json",
        @"radio/radio.json",
        @"switch/switch.json",
        @"inbox/inbox.json",
        @"journey/journey.json",
        @"player/player.json",
        @"chat/chat.json",
        @"glass/glass.json",
        @"stack/shelf.json",
        @"stack/place.json",
        @"stack/stop.json",
        @"stack/memo.json",
        @"market/home.json",
        @"market/shop.json",
        @"market/cart.json",
        @"market/checkout.json",
        @"market/result.json",
        @"market/orders.json",
        @"market/mine.json"
    ];
    for (NSString *relative in relatives) {
        NSURL *file = [root URLByAppendingPathComponent:relative];
        XCTAssertTrue(OTIsFile(file.path), @"缺少 %@", file.path);
        NSError *readError = nil;
        NSString *text = [NSString stringWithContentsOfURL:file encoding:NSUTF8StringEncoding error:&readError];
        XCTAssertNil(readError);
        NSError *parseError = nil;
        XCTAssertNotNil([TemplateJsonParser parseJSON:text error:&parseError], @"%@", relative);
        XCTAssertNil(parseError, @"%@", parseError);
    }
}

- (void)testParsesLayoutStyleAndChangeFields {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": {\n"
        @"    \"type\": \"column\",\n"
        @"    \"id\": \"page\",\n"
        @"    \"scroll\": true,\n"
        @"    \"visible\": \"$shown\",\n"
        @"    \"onChange\": [\"renamed\"],\n"
        @"    \"layout\": {\n"
        @"      \"width\": \"fill\",\n"
        @"      \"height\": \"fill\",\n"
        @"      \"margin\": { \"start\": 8, \"end\": 4, \"top\": 2, \"bottom\": 1 },\n"
        @"      \"wrap\": true,\n"
        @"      \"aspectRatio\": 1.5,\n"
        @"      \"alignSelf\": \"stretch\",\n"
        @"      \"minWidth\": \"fill\",\n"
        @"      \"maxHeight\": \"wrap\"\n"
        @"    },\n"
        @"    \"children\": [\n"
        @"      {\n"
        @"        \"type\": \"text\",\n"
        @"        \"id\": \"title\",\n"
        @"        \"text\": \"Hi\",\n"
        @"        \"layout\": { \"width\": \"fill\", \"height\": \"wrap\" },\n"
        @"        \"style\": { \"maxLines\": 2, \"ellipsis\": true, \"fontWeight\": \"medium\" }\n"
        @"      },\n"
        @"      {\n"
        @"        \"type\": \"image\",\n"
        @"        \"src\": \"res:cover\",\n"
        @"        \"layout\": { \"width\": 40, \"height\": 40 },\n"
        @"        \"style\": { \"fit\": \"contain\", \"placeholder\": \"#112233\" }\n"
        @"      },\n"
        @"      {\n"
        @"        \"type\": \"input\",\n"
        @"        \"layout\": { \"width\": \"fill\", \"height\": 44 },\n"
        @"        \"style\": { \"lines\": 3 }\n"
        @"      },\n"
        @"      {\n"
        @"        \"type\": \"list\",\n"
        @"        \"id\": \"feed\",\n"
        @"        \"data\": \"$items\",\n"
        @"        \"layout\": { \"width\": \"fill\", \"height\": 80 },\n"
        @"        \"item\": {\n"
        @"          \"type\": \"text\",\n"
        @"          \"text\": \"$title\",\n"
        @"          \"layout\": { \"width\": \"fill\", \"height\": 20 }\n"
        @"        }\n"
        @"      }\n"
        @"    ]\n"
        @"  },\n"
        @"  \"events\": {\n"
        @"    \"renamed\": { \"action\": \"toast\", \"message\": \"ok\" }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    ParsedNode *page = parsed.root;
    expect(page.attrs[[TemplateKey ATTR_SCROLL]], @"true");
    expect(page.attrs[[TemplateKey ATTR_VISIBLE]], @"$shown");
    expect(page.attrs[[TemplateKey ATTR_ONCHANGE]], @"renamed");
    expect(page.attrs[[TemplateKey ATTR_MARGIN_START]], @"8");
    expect(page.attrs[[TemplateKey ATTR_MARGIN_END]], @"4");
    expect(page.attrs[[TemplateKey ATTR_MARGIN_TOP]], @"2");
    expect(page.attrs[[TemplateKey ATTR_MARGIN_BOTTOM]], @"1");
    XCTAssertNil(page.attrs[[TemplateKey ATTR_MARGIN]]);
    expect(page.attrs[[TemplateKey ATTR_FLEX_WRAP]], @"wrap");
    expect(page.attrs[[TemplateKey ATTR_ASPECT_RATIO]], @"1.5");
    expect(page.attrs[[TemplateKey ATTR_ALIGN_SELF]], @"stretch");
    expect(page.attrs[[TemplateKey ATTR_MIN_WIDTH]], @"match_parent");
    expect(page.attrs[[TemplateKey ATTR_MAX_HEIGHT]], @"wrap_content");
    ParsedNode *title = page.children[0];
    expect(title.attrs[[TemplateKey ATTR_MAX_LINES]], @"2");
    expect(title.attrs[[TemplateKey ATTR_ELLIPSIS]], @"true");
    expect(title.attrs[[TemplateKey ATTR_FONT_WEIGHT]], @"medium");
    ParsedNode *image = page.children[1];
    expect(image.attrs[[TemplateKey ATTR_IMAGE_FIT]], @"contain");
    expect(image.attrs[[TemplateKey ATTR_PLACEHOLDER]], @"#112233");
    expect(page.children[2].attrs[[TemplateKey ATTR_LINES]], @"3");
}

- (void)testParsesUpdateRemoveReplacePopToAndHost {
    ParsedTemplate *parsed = [self parse:
        @"{\n"
        @"  \"layout\": {\n"
        @"    \"type\": \"list\",\n"
        @"    \"id\": \"feed\",\n"
        @"    \"data\": \"$items\",\n"
        @"    \"layout\": { \"width\": \"fill\", \"height\": 80 },\n"
        @"    \"item\": {\n"
        @"      \"type\": \"text\",\n"
        @"      \"text\": \"$title\",\n"
        @"      \"layout\": { \"width\": \"fill\", \"height\": 20 }\n"
        @"    }\n"
        @"  },\n"
        @"  \"events\": {\n"
        @"    \"edit\": {\n"
        @"      \"action\": \"update\",\n"
        @"      \"list\": \"feed\",\n"
        @"      \"index\": \"$row\",\n"
        @"      \"item\": { \"title\": \"新\" }\n"
        @"    },\n"
        @"    \"drop\": { \"action\": \"remove\", \"list\": \"feed\", \"index\": 0 },\n"
        @"    \"swap\": {\n"
        @"      \"action\": \"replace\",\n"
        @"      \"page\": \"detail\",\n"
        @"      \"params\": { \"city\": \"上海\" }\n"
        @"    },\n"
        @"    \"backTo\": { \"action\": \"popTo\", \"page\": \"$page\" },\n"
        @"    \"share\": {\n"
        @"      \"action\": \"host\",\n"
        @"      \"name\": \"$sheet\",\n"
        @"      \"params\": { \"ok\": true }\n"
        @"    }\n"
        @"  }\n"
        @"}"];
    if (parsed == nil) return;
    JSONObject *update = parsed.events[@"edit"];
    XCTAssertNotNil(update);
    expect([update getString:@"class"], @"list");
    JSONObject *updateParams = [update getJSONObject:@"params"];
    XCTAssertNotNil(updateParams);
    expect([updateParams getString:@"fun"], @"update");
    expect([updateParams getString:@"id"], @"feed");
    expect([updateParams getString:@"index"], @"$row");
    expect([[updateParams getJSONObject:@"item"] getString:@"title"], @"新");
    JSONObject *remove = [parsed.events[@"drop"] getJSONObject:@"params"];
    XCTAssertNotNil(remove);
    expect([remove getString:@"fun"], @"remove");
    expect([remove getString:@"id"], @"feed");
    expect([remove getString:@"index"], @"0");
    JSONObject *replace = parsed.events[@"swap"];
    XCTAssertNotNil(replace);
    expect([replace getString:@"class"], @"nav");
    JSONObject *replaceParams = [replace getJSONObject:@"params"];
    XCTAssertNotNil(replaceParams);
    expect([replaceParams getString:@"fun"], @"replace");
    expect([replaceParams getString:@"page"], @"detail");
    expect([[replaceParams getJSONObject:@"params"] getString:@"city"], @"上海");
    JSONObject *popTo = [parsed.events[@"backTo"] getJSONObject:@"params"];
    XCTAssertNotNil(popTo);
    expect([popTo getString:@"fun"], @"popTo");
    expect([popTo getString:@"page"], @"$page");
    XCTAssertTrue(![popTo containsKey:@"params"]);
    JSONObject *host = parsed.events[@"share"];
    XCTAssertNotNil(host);
    expect([host getString:@"class"], @"nav");
    JSONObject *hostParams = [host getJSONObject:@"params"];
    XCTAssertNotNil(hostParams);
    expect([hostParams getString:@"fun"], @"host");
    expect([hostParams getString:@"name"], @"$sheet");
    expectValue([[hostParams getJSONObject:@"params"] get:@"ok"], [JSONValue bool:YES]);
}

- (void)testRejectsScrollWrapStyleAndIndexMistakes {
    assertFails(@"$.layout.scroll 不是这里能写的字段", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"text\", \"text\": \"Hi\", \"scroll\": true, \"layout\": {\"width\": 1, \"height\": 1}}}" error:error];
    });
    assertFails(@"$.layout.layout.wrap 不是这里能写的字段", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"text\", \"text\": \"Hi\", \"layout\": {\"width\": 1, \"height\": 1, \"wrap\": true}}}" error:error];
    });
    assertFails(@"$.layout.style.fontWeight 只能是 regular、medium、bold", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"text\", \"text\": \"Hi\", \"layout\": {\"width\": 1, \"height\": 1}, \"style\": {\"fontWeight\": \"heavy\"}}}" error:error];
    });
    assertFails(@"$.layout.style.fit 只能是 cover、contain、fill", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"image\", \"src\": \"res:cover\", \"layout\": {\"width\": 1, \"height\": 1}, \"style\": {\"fit\": \"tile\"}}}" error:error];
    });
    assertFails(@"$.layout.onChange 不能是空数组", ^(NSError **error) {
        [TemplateJsonParser parseJSON:@"{\"layout\": {\"type\": \"text\", \"text\": \"Hi\", \"layout\": {\"width\": 1, \"height\": 1}, \"onChange\": []}}" error:error];
    });
    assertFails(@"$.events.edit.index 不能是负数", ^(NSError **error) {
        [TemplateJsonParser parseJSON:
            @"{\n"
            @"  \"layout\": { \"type\": \"text\", \"text\": \"Hi\", \"layout\": { \"width\": 1, \"height\": 1 } },\n"
            @"  \"events\": { \"edit\": { \"action\": \"update\", \"list\": \"feed\", \"index\": -1, \"item\": { \"title\": \"x\" } } }\n"
            @"}"
            error:error];
    });
}

@end
