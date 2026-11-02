#import "TestSupport.h"
#import "PageRouteParser.h"

@interface PageRouteParserTests : XCTestCase
@end

@implementation PageRouteParserTests

- (void)testParsesRouteWithOptionalData {
    NSError *error = nil;
    PageRouteTable *table = [PageRouteParser parseJSON:
        @"{\n"
        @"  \"start\": \"home\",\n"
        @"  \"pages\": {\n"
        @"    \"home\": {\n"
        @"      \"template\": \"templates/stack/home.json\",\n"
        @"      \"data\": \"templates/stack/mock-data/home.json\"\n"
        @"    },\n"
        @"    \"detail\": {\n"
        @"      \"template\": \"templates/stack/detail.json\"\n"
        @"    }\n"
        @"  }\n"
        @"}"
        error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(@"home", table.start);
    XCTAssertEqual(2, (NSInteger)table.pages.count);
    XCTAssertEqualObjects(@"templates/stack/home.json", table.pages[@"home"].template);
    XCTAssertEqualObjects(@"templates/stack/mock-data/home.json", table.pages[@"home"].data);
    XCTAssertEqualObjects(@"templates/stack/detail.json", table.pages[@"detail"].template);
    XCTAssertNil(table.pages[@"detail"].data);
}

- (void)testRejectsMissingStart {
    assertFails(@"$ 缺少 start", ^(NSError **error) {
        [PageRouteParser parseJSON:
            @"{\n"
            @"  \"pages\": {\n"
            @"    \"home\": { \"template\": \"templates/stack/home.json\" }\n"
            @"  }\n"
            @"}"
            error:error];
    });
}

- (void)testRejectsMissingPages {
    assertFails(@"$ 缺少 pages", ^(NSError **error) {
        [PageRouteParser parseJSON:@"{\"start\": \"home\"}" error:error];
    });
}

- (void)testRejectsMissingTemplate {
    assertFails(@"$.pages.home 缺少 template", ^(NSError **error) {
        [PageRouteParser parseJSON:
            @"{\n"
            @"  \"start\": \"home\",\n"
            @"  \"pages\": {\n"
            @"    \"home\": { \"data\": \"templates/stack/mock-data/home.json\" }\n"
            @"  }\n"
            @"}"
            error:error];
    });
}

- (void)testRejectsEmptyPages {
    assertFails(@"$.pages 不能是空对象", ^(NSError **error) {
        [PageRouteParser parseJSON:@"{\"start\": \"home\", \"pages\": {}}" error:error];
    });
}

- (void)testRejectsEmptyTemplate {
    assertFails(@"$.pages.home.template 不能是空字符串", ^(NSError **error) {
        [PageRouteParser parseJSON:
            @"{\n"
            @"  \"start\": \"home\",\n"
            @"  \"pages\": {\n"
            @"    \"home\": { \"template\": \"\" }\n"
            @"  }\n"
            @"}"
            error:error];
    });
}

- (void)testRejectsIllegalPageName {
    assertFails(@"$.pages 的页面名「1ab」必须是字母或下划线开头的标识符", ^(NSError **error) {
        [PageRouteParser parseJSON:
            @"{\n"
            @"  \"start\": \"home\",\n"
            @"  \"pages\": {\n"
            @"    \"home\": { \"template\": \"templates/stack/home.json\" },\n"
            @"    \"1ab\": { \"template\": \"templates/stack/detail.json\" }\n"
            @"  }\n"
            @"}"
            error:error];
    });
}

- (void)testRejectsIllegalStartName {
    assertFails(@"$.start「1ab」必须是字母或下划线开头的标识符", ^(NSError **error) {
        [PageRouteParser parseJSON:
            @"{\n"
            @"  \"start\": \"1ab\",\n"
            @"  \"pages\": {\n"
            @"    \"home\": { \"template\": \"templates/stack/home.json\" }\n"
            @"  }\n"
            @"}"
            error:error];
    });
}

- (void)testRejectsStartMissingFromPages {
    assertFails(@"$.start 引用了不存在的页面 home", ^(NSError **error) {
        [PageRouteParser parseJSON:
            @"{\n"
            @"  \"start\": \"home\",\n"
            @"  \"pages\": {\n"
            @"    \"detail\": { \"template\": \"templates/stack/detail.json\" }\n"
            @"  }\n"
            @"}"
            error:error];
    });
}

- (void)testRejectsUnknownRootField {
    assertFails(@"$.version 不是这里能写的字段", ^(NSError **error) {
        [PageRouteParser parseJSON:
            @"{\n"
            @"  \"start\": \"home\",\n"
            @"  \"version\": 1,\n"
            @"  \"pages\": {\n"
            @"    \"home\": { \"template\": \"templates/stack/home.json\" }\n"
            @"  }\n"
            @"}"
            error:error];
    });
}

- (void)testRejectsUnknownPageField {
    assertFails(@"$.pages.home.animation 不是这里能写的字段", ^(NSError **error) {
        [PageRouteParser parseJSON:
            @"{\n"
            @"  \"start\": \"home\",\n"
            @"  \"pages\": {\n"
            @"    \"home\": { \"template\": \"templates/stack/home.json\", \"animation\": \"fade\" }\n"
            @"  }\n"
            @"}"
            error:error];
    });
}

- (void)testRejectsMalformedRouteJson {
    assertFailsPrefix(@"路由不是合法 JSON：", ^(NSError **error) {
        [PageRouteParser parseJSON:@"{" error:error];
    });
}

- (void)testRejectsTemplateThatIsNotAString {
    assertFails(@"$.pages.home.template 必须是字符串", ^(NSError **error) {
        [PageRouteParser parseJSON:
            @"{\n"
            @"  \"start\": \"home\",\n"
            @"  \"pages\": {\n"
            @"    \"home\": { \"template\": 1 }\n"
            @"  }\n"
            @"}"
            error:error];
    });
}

- (void)testRejectsRouteThatIsNotAnObject {
    assertFails(@"路由必须是 JSON 对象", ^(NSError **error) {
        [PageRouteParser parseJSON:@"null" error:error];
    });
    assertFailsPrefix(@"路由不是合法 JSON：", ^(NSError **error) {
        [PageRouteParser parseJSON:@"[]" error:error];
    });
}

@end
