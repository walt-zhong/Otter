import XCTest
@testable import OtterCore

final class PageRouteParserTests: XCTestCase {
    func testParsesRouteWithOptionalData() throws {
        let table = try PageRouteParser.parse(
            """
            {
              "start": "home",
              "pages": {
                "home": {
                  "template": "templates/stack/home.json",
                  "data": "templates/stack/mock-data/home.json"
                },
                "detail": {
                  "template": "templates/stack/detail.json"
                }
              }
            }
            """
        )

        XCTAssertEqual("home", table.start)
        XCTAssertEqual(2, table.pages.count)
        XCTAssertEqual("templates/stack/home.json", table.pages["home"]?.template)
        XCTAssertEqual("templates/stack/mock-data/home.json", table.pages["home"]?.data)
        XCTAssertEqual("templates/stack/detail.json", table.pages["detail"]?.template)
        XCTAssertNil(table.pages["detail"]?.data)
    }

    func testRejectsMissingStart() {
        assertFails("$ 缺少 start") {
            try PageRouteParser.parse(
                """
                {
                  "pages": {
                    "home": { "template": "templates/stack/home.json" }
                  }
                }
                """
            )
        }
    }

    func testRejectsMissingPages() {
        assertFails("$ 缺少 pages") {
            try PageRouteParser.parse(
                """
                { "start": "home" }
                """
            )
        }
    }

    func testRejectsMissingTemplate() {
        assertFails("$.pages.home 缺少 template") {
            try PageRouteParser.parse(
                """
                {
                  "start": "home",
                  "pages": {
                    "home": { "data": "templates/stack/mock-data/home.json" }
                  }
                }
                """
            )
        }
    }

    func testRejectsEmptyPages() {
        assertFails("$.pages 不能是空对象") {
            try PageRouteParser.parse(
                """
                { "start": "home", "pages": {} }
                """
            )
        }
    }

    func testRejectsEmptyTemplate() {
        assertFails("$.pages.home.template 不能是空字符串") {
            try PageRouteParser.parse(
                """
                {
                  "start": "home",
                  "pages": {
                    "home": { "template": "" }
                  }
                }
                """
            )
        }
    }

    func testRejectsIllegalPageName() {
        assertFails("$.pages 的页面名「1ab」必须是字母或下划线开头的标识符") {
            try PageRouteParser.parse(
                """
                {
                  "start": "home",
                  "pages": {
                    "home": { "template": "templates/stack/home.json" },
                    "1ab": { "template": "templates/stack/detail.json" }
                  }
                }
                """
            )
        }
    }

    func testRejectsIllegalStartName() {
        assertFails("$.start「1ab」必须是字母或下划线开头的标识符") {
            try PageRouteParser.parse(
                """
                {
                  "start": "1ab",
                  "pages": {
                    "home": { "template": "templates/stack/home.json" }
                  }
                }
                """
            )
        }
    }

    func testRejectsStartMissingFromPages() {
        assertFails("$.start 引用了不存在的页面 home") {
            try PageRouteParser.parse(
                """
                {
                  "start": "home",
                  "pages": {
                    "detail": { "template": "templates/stack/detail.json" }
                  }
                }
                """
            )
        }
    }

    func testRejectsUnknownRootField() {
        assertFails("$.version 不是这里能写的字段") {
            try PageRouteParser.parse(
                """
                {
                  "start": "home",
                  "version": 1,
                  "pages": {
                    "home": { "template": "templates/stack/home.json" }
                  }
                }
                """
            )
        }
    }

    func testRejectsUnknownPageField() {
        assertFails("$.pages.home.animation 不是这里能写的字段") {
            try PageRouteParser.parse(
                """
                {
                  "start": "home",
                  "pages": {
                    "home": { "template": "templates/stack/home.json", "animation": "fade" }
                  }
                }
                """
            )
        }
    }

    func testRejectsMalformedRouteJson() {
        assertFailsPrefix("路由不是合法 JSON：") {
            try PageRouteParser.parse("{")
        }
    }

    func testRejectsTemplateThatIsNotAString() {
        assertFails("$.pages.home.template 必须是字符串") {
            try PageRouteParser.parse(
                """
                {
                  "start": "home",
                  "pages": {
                    "home": { "template": 1 }
                  }
                }
                """
            )
        }
    }

    func testRejectsRouteThatIsNotAnObject() {
        assertFails("路由必须是 JSON 对象") {
            try PageRouteParser.parse("null")
        }
        assertFailsPrefix("路由不是合法 JSON：") {
            try PageRouteParser.parse("[]")
        }
    }
}
