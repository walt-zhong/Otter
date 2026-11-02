#import "TestSupport.h"
#import "PageParams.h"

@interface PageParamsTests : XCTestCase
@end

@implementation PageParamsTests

- (void)testMergeOverwritesSameKeys {
    JSONObject *baseNested = [[JSONObject alloc] init];
    baseNested[@"a"] = [JSONValue number:[JSONNumber intNumber:1]];
    baseNested[@"b"] = [JSONValue number:[JSONNumber intNumber:2]];
    JSONObject *overlayNested = [[JSONObject alloc] init];
    overlayNested[@"b"] = [JSONValue number:[JSONNumber intNumber:9]];
    JSONObject *base = [[JSONObject alloc] init];
    base[@"name"] = [JSONValue string:@"旧"];
    base[@"meta"] = [JSONValue object:baseNested];
    JSONObject *overlay = [[JSONObject alloc] init];
    overlay[@"name"] = [JSONValue string:@"新"];
    overlay[@"meta"] = [JSONValue object:overlayNested];
    overlay[@"extra"] = [JSONValue string:@"加上"];

    JSONObject *merged = [PageParams merge:base overlay:overlay];

    XCTAssertEqualObjects([JSONValue string:@"新"], [merged get:@"name"]);
    XCTAssertEqualObjects([JSONValue string:@"加上"], [merged get:@"extra"]);
    JSONObject *meta = [merged getJSONObject:@"meta"];
    XCTAssertEqualObjects([JSONValue number:[JSONNumber intNumber:9]], [meta get:@"b"]);
    XCTAssertEqual(NO, [meta containsKey:@"a"]);
    XCTAssertEqualObjects([JSONValue string:@"旧"], [base get:@"name"]);
    XCTAssertEqualObjects([JSONValue number:[JSONNumber intNumber:1]], [baseNested get:@"a"]);
    XCTAssertEqualObjects([JSONValue number:[JSONNumber intNumber:2]], [baseNested get:@"b"]);
    XCTAssertEqualObjects([JSONValue number:[JSONNumber intNumber:9]], [overlayNested get:@"b"]);
    XCTAssertTrue(merged != base);
    XCTAssertTrue(merged != overlay);
}

- (void)testFalseAndZeroOverwriteOldValues {
    JSONObject *base = [[JSONObject alloc] init];
    base[@"ok"] = [JSONValue bool:YES];
    base[@"count"] = [JSONValue number:[JSONNumber intNumber:1]];
    base[@"name"] = [JSONValue string:@"留"];
    JSONObject *overlay = [[JSONObject alloc] init];
    overlay[@"ok"] = [JSONValue bool:NO];
    overlay[@"count"] = [JSONValue number:[JSONNumber intNumber:0]];

    JSONObject *merged = [PageParams merge:base overlay:overlay];

    XCTAssertEqualObjects([JSONValue bool:NO], [merged get:@"ok"]);
    XCTAssertEqualObjects([JSONValue number:[JSONNumber intNumber:0]], [merged get:@"count"]);
    XCTAssertEqualObjects([JSONValue string:@"留"], [merged get:@"name"]);
    XCTAssertEqualObjects([JSONValue bool:YES], [base get:@"ok"]);
    XCTAssertEqualObjects([JSONValue number:[JSONNumber intNumber:1]], [base get:@"count"]);
    XCTAssertTrue(merged != base);
    XCTAssertTrue(merged != overlay);
}

- (void)testNullBaseReturnsCopyOfOverlay {
    JSONObject *overlay = [[JSONObject alloc] init];
    overlay[@"city"] = [JSONValue string:@"上海"];
    overlay[@"ok"] = [JSONValue bool:NO];
    overlay[@"count"] = [JSONValue number:[JSONNumber intNumber:0]];

    JSONObject *merged = [PageParams merge:nil overlay:overlay];

    XCTAssertEqualObjects(overlay, merged);
    XCTAssertEqualObjects([JSONValue string:@"上海"], [merged get:@"city"]);
    XCTAssertEqualObjects([JSONValue bool:NO], [merged get:@"ok"]);
    XCTAssertEqualObjects([JSONValue number:[JSONNumber intNumber:0]], [merged get:@"count"]);
    XCTAssertTrue(merged != overlay);
    merged[@"city"] = [JSONValue string:@"改了"];
    XCTAssertEqualObjects([JSONValue string:@"上海"], [overlay get:@"city"]);
}

- (void)testEmptyOverlayLeavesBaseUnchanged {
    JSONObject *base = [[JSONObject alloc] init];
    base[@"city"] = [JSONValue string:@"北京"];
    base[@"ok"] = [JSONValue bool:NO];
    base[@"count"] = [JSONValue number:[JSONNumber intNumber:0]];
    JSONObject *overlay = [[JSONObject alloc] init];

    JSONObject *merged = [PageParams merge:base overlay:overlay];
    JSONObject *fromNull = [PageParams merge:base overlay:nil];

    XCTAssertEqualObjects(base, merged);
    XCTAssertEqualObjects(base, fromNull);
    XCTAssertTrue(merged != base);
    XCTAssertTrue(merged != overlay);
    XCTAssertTrue(fromNull != base);
    merged[@"city"] = [JSONValue string:@"改了"];
    XCTAssertEqualObjects([JSONValue string:@"北京"], [base get:@"city"]);
    XCTAssertEqualObjects([JSONValue bool:NO], [base get:@"ok"]);
    XCTAssertEqualObjects([JSONValue number:[JSONNumber intNumber:0]], [base get:@"count"]);
    XCTAssertEqualObjects([JSONValue string:@"北京"], [fromNull get:@"city"]);
}

- (void)testEvaluateKeepsPlainValuesAndWritesResolveResult {
    JSONObject *raw = [[JSONObject alloc] init];
    raw[@"label"] = [JSONValue string:@"北京"];
    raw[@"city"] = [JSONValue string:@"$city"];
    raw[@"count"] = [JSONValue number:[JSONNumber intNumber:2]];
    raw[@"ok"] = [JSONValue bool:YES];
    raw[@"n"] = [JSONValue string:@"$n"];
    raw[@"flag"] = [JSONValue string:@"$flag"];
    NSMutableArray<NSString *> *seen = [NSMutableArray array];

    JSONObject *result = [PageParams evaluate:raw resolver:^JSONValue *(NSString *expression) {
        [seen addObject:expression];
        if ([expression isEqualToString:@"$city"]) {
            return [JSONValue string:@"上海"];
        }
        if ([expression isEqualToString:@"$n"]) {
            return [JSONValue number:[JSONNumber intNumber:0]];
        }
        if ([expression isEqualToString:@"$flag"]) {
            return [JSONValue bool:NO];
        }
        XCTFail(@"unexpected %@", expression);
        return nil;
    }];

    XCTAssertEqualObjects(([NSSet setWithObjects:@"$city", @"$n", @"$flag", nil]), ([NSSet setWithArray:seen]));
    XCTAssertEqual(3, (NSInteger)seen.count);
    XCTAssertEqualObjects([JSONValue string:@"北京"], [result get:@"label"]);
    XCTAssertEqualObjects([JSONValue string:@"上海"], [result get:@"city"]);
    XCTAssertEqualObjects([JSONValue number:[JSONNumber intNumber:2]], [result get:@"count"]);
    XCTAssertEqualObjects([JSONValue bool:YES], [result get:@"ok"]);
    XCTAssertEqualObjects([JSONValue number:[JSONNumber intNumber:0]], [result get:@"n"]);
    XCTAssertEqualObjects([JSONValue bool:NO], [result get:@"flag"]);
    XCTAssertEqual(raw.size, result.size);
    XCTAssertEqualObjects([JSONValue string:@"北京"], [raw get:@"label"]);
    XCTAssertEqualObjects([JSONValue string:@"$city"], [raw get:@"city"]);
    XCTAssertTrue(result != raw);
}

- (void)testEvaluateKeepsDollarStringWhenResolveReturnsNull {
    JSONObject *marker = [[JSONObject alloc] init];
    marker[@"id"] = [JSONValue number:[JSONNumber intNumber:1]];
    JSONObject *raw = [[JSONObject alloc] init];
    raw[@"city"] = [JSONValue string:@"$city"];
    raw[@"item"] = [JSONValue string:@"$item"];
    raw[@"label"] = [JSONValue string:@"原文"];

    JSONObject *result = [PageParams evaluate:raw resolver:^JSONValue *(NSString *expression) {
        if ([expression isEqualToString:@"$city"]) {
            return nil;
        }
        if ([expression isEqualToString:@"$item"]) {
            return [JSONValue object:marker];
        }
        XCTFail(@"unexpected %@", expression);
        return nil;
    }];

    XCTAssertEqualObjects([JSONValue string:@"$city"], [result get:@"city"]);
    XCTAssertTrue([result get:@"item"].jsonObject == marker);
    XCTAssertEqualObjects([JSONValue string:@"原文"], [result get:@"label"]);
    XCTAssertEqualObjects([JSONValue string:@"$city"], [raw get:@"city"]);
    XCTAssertEqualObjects([JSONValue string:@"$item"], [raw get:@"item"]);
    XCTAssertTrue(result != raw);
}

- (void)testEvaluateCopiesNestedTemplateValues {
    JSONObject *nested = [[JSONObject alloc] init];
    nested[@"name"] = [JSONValue string:@"$city"];
    JSONArray *tags = [[JSONArray alloc] init];
    [tags add:[JSONValue string:@"$city"]];
    JSONObject *raw = [[JSONObject alloc] init];
    raw[@"meta"] = [JSONValue object:nested];
    raw[@"tags"] = [JSONValue array:tags];

    JSONObject *result = [PageParams evaluate:raw resolver:^JSONValue *(NSString *expression) {
        (void)expression;
        return [JSONValue string:@"上海"];
    }];

    JSONObject *meta = [result getJSONObject:@"meta"];
    XCTAssertEqualObjects([JSONValue string:@"上海"], [meta get:@"name"]);
    XCTAssertEqualObjects([JSONValue string:@"上海"], [[result getJSONArray:@"tags"] get:0]);
    XCTAssertEqualObjects([JSONValue string:@"$city"], [nested get:@"name"]);
    XCTAssertTrue(meta != nested);
}

- (void)testMatchesComparesOnlyOverlayKeys {
    JSONArray *lines = [[JSONArray alloc] init];
    [lines add:[JSONValue string:@"一句"]];
    JSONObject *data = [[JSONObject alloc] init];
    data[@"name"] = [JSONValue string:@"窗边"];
    data[@"count"] = [JSONValue number:[JSONNumber intNumber:1]];
    data[@"ok"] = [JSONValue bool:NO];
    data[@"lines"] = [JSONValue array:lines];
    JSONObject *same = [[JSONObject alloc] init];
    same[@"name"] = [JSONValue string:@"窗边"];
    same[@"count"] = [JSONValue number:[JSONNumber doubleNumber:1.0]];
    same[@"ok"] = [JSONValue bool:NO];
    JSONObject *renamed = [[JSONObject alloc] init];
    renamed[@"name"] = [JSONValue string:@"今日日晒"];
    JSONObject *empty = [[JSONObject alloc] init];

    XCTAssertTrue([PageParams matches:data overlay:same]);
    XCTAssertTrue([PageParams matches:data overlay:empty]);
    XCTAssertTrue([PageParams matches:data overlay:nil]);
    XCTAssertTrue(![PageParams matches:data overlay:renamed]);
    XCTAssertTrue(![PageParams matches:nil overlay:same]);
}

@end
