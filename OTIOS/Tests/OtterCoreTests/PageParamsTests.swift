import XCTest
@testable import OtterCore

final class PageParamsTests: XCTestCase {
    func testMergeOverwritesSameKeys() {
        let baseNested = JSONObject()
        baseNested["a"] = .number(.int(1))
        baseNested["b"] = .number(.int(2))
        let overlayNested = JSONObject()
        overlayNested["b"] = .number(.int(9))
        let base = JSONObject()
        base["name"] = .string("旧")
        base["meta"] = .object(baseNested)
        let overlay = JSONObject()
        overlay["name"] = .string("新")
        overlay["meta"] = .object(overlayNested)
        overlay["extra"] = .string("加上")

        let merged = PageParams.merge(base, overlay)

        XCTAssertEqual(.string("新"), merged?.get("name"))
        XCTAssertEqual(.string("加上"), merged?.get("extra"))
        let meta = merged?.getJSONObject("meta")
        XCTAssertEqual(.number(.int(9)), meta?.get("b"))
        XCTAssertEqual(false, meta?.containsKey("a"))
        XCTAssertEqual(.string("旧"), base.get("name"))
        XCTAssertEqual(.number(.int(1)), baseNested.get("a"))
        XCTAssertEqual(.number(.int(2)), baseNested.get("b"))
        XCTAssertEqual(.number(.int(9)), overlayNested.get("b"))
        XCTAssertTrue(merged !== base)
        XCTAssertTrue(merged !== overlay)
    }

    func testFalseAndZeroOverwriteOldValues() {
        let base = JSONObject()
        base["ok"] = .bool(true)
        base["count"] = .number(.int(1))
        base["name"] = .string("留")
        let overlay = JSONObject()
        overlay["ok"] = .bool(false)
        overlay["count"] = .number(.int(0))

        let merged = PageParams.merge(base, overlay)

        XCTAssertEqual(.bool(false), merged?.get("ok"))
        XCTAssertEqual(.number(.int(0)), merged?.get("count"))
        XCTAssertEqual(.string("留"), merged?.get("name"))
        XCTAssertEqual(.bool(true), base.get("ok"))
        XCTAssertEqual(.number(.int(1)), base.get("count"))
        XCTAssertTrue(merged !== base)
        XCTAssertTrue(merged !== overlay)
    }

    func testNullBaseReturnsCopyOfOverlay() {
        let overlay = JSONObject()
        overlay["city"] = .string("上海")
        overlay["ok"] = .bool(false)
        overlay["count"] = .number(.int(0))

        let merged = PageParams.merge(nil, overlay)

        XCTAssertEqual(overlay, merged)
        XCTAssertEqual(.string("上海"), merged?.get("city"))
        XCTAssertEqual(.bool(false), merged?.get("ok"))
        XCTAssertEqual(.number(.int(0)), merged?.get("count"))
        XCTAssertTrue(merged !== overlay)
        merged?["city"] = .string("改了")
        XCTAssertEqual(.string("上海"), overlay.get("city"))
    }

    func testEmptyOverlayLeavesBaseUnchanged() {
        let base = JSONObject()
        base["city"] = .string("北京")
        base["ok"] = .bool(false)
        base["count"] = .number(.int(0))
        let overlay = JSONObject()

        let merged = PageParams.merge(base, overlay)
        let fromNull = PageParams.merge(base, nil)

        XCTAssertEqual(base, merged)
        XCTAssertEqual(base, fromNull)
        XCTAssertTrue(merged !== base)
        XCTAssertTrue(merged !== overlay)
        XCTAssertTrue(fromNull !== base)
        merged?["city"] = .string("改了")
        XCTAssertEqual(.string("北京"), base.get("city"))
        XCTAssertEqual(.bool(false), base.get("ok"))
        XCTAssertEqual(.number(.int(0)), base.get("count"))
        XCTAssertEqual(.string("北京"), fromNull?.get("city"))
    }

    func testEvaluateKeepsPlainValuesAndWritesResolveResult() {
        let raw = JSONObject()
        raw["label"] = .string("北京")
        raw["city"] = .string("$city")
        raw["count"] = .number(.int(2))
        raw["ok"] = .bool(true)
        raw["n"] = .string("$n")
        raw["flag"] = .string("$flag")
        var seen: [String] = []

        let result = PageParams.evaluate(raw) { expression in
            seen.append(expression)
            switch expression {
            case "$city":
                return .string("上海")
            case "$n":
                return .number(.int(0))
            case "$flag":
                return .bool(false)
            default:
                XCTFail("unexpected \(expression)")
                return nil
            }
        }

        XCTAssertEqual(Set(["$city", "$n", "$flag"]), Set(seen))
        XCTAssertEqual(3, seen.count)
        XCTAssertEqual(.string("北京"), result.get("label"))
        XCTAssertEqual(.string("上海"), result.get("city"))
        XCTAssertEqual(.number(.int(2)), result.get("count"))
        XCTAssertEqual(.bool(true), result.get("ok"))
        XCTAssertEqual(.number(.int(0)), result.get("n"))
        XCTAssertEqual(.bool(false), result.get("flag"))
        XCTAssertEqual(raw.size, result.size)
        XCTAssertEqual(.string("北京"), raw.get("label"))
        XCTAssertEqual(.string("$city"), raw.get("city"))
        XCTAssertTrue(result !== raw)
    }

    func testEvaluateKeepsDollarStringWhenResolveReturnsNull() {
        let marker = JSONObject()
        marker["id"] = .number(.int(1))
        let raw = JSONObject()
        raw["city"] = .string("$city")
        raw["item"] = .string("$item")
        raw["label"] = .string("原文")

        let result = PageParams.evaluate(raw) { expression in
            switch expression {
            case "$city":
                return nil
            case "$item":
                return .object(marker)
            default:
                XCTFail("unexpected \(expression)")
                return nil
            }
        }

        XCTAssertEqual(.string("$city"), result.get("city"))
        XCTAssertTrue(result.get("item")?.jsonObject === marker)
        XCTAssertEqual(.string("原文"), result.get("label"))
        XCTAssertEqual(.string("$city"), raw.get("city"))
        XCTAssertEqual(.string("$item"), raw.get("item"))
        XCTAssertTrue(result !== raw)
    }

    func testEvaluateCopiesNestedTemplateValues() {
        let nested = JSONObject()
        nested["name"] = .string("$city")
        let tags = JSONArray()
        tags.add(.string("$city"))
        let raw = JSONObject()
        raw["meta"] = .object(nested)
        raw["tags"] = .array(tags)

        let result = PageParams.evaluate(raw) { _ in .string("上海") }

        let meta = result.getJSONObject("meta")
        XCTAssertEqual(.string("上海"), meta?.get("name"))
        XCTAssertEqual(.string("上海"), result.getJSONArray("tags")?.get(0))
        XCTAssertEqual(.string("$city"), nested.get("name"))
        XCTAssertTrue(meta !== nested)
    }

    func testMatchesComparesOnlyOverlayKeys() {
        let lines = JSONArray()
        lines.add(.string("一句"))
        let data = JSONObject()
        data["name"] = .string("窗边")
        data["count"] = .number(.int(1))
        data["ok"] = .bool(false)
        data["lines"] = .array(lines)
        let same = JSONObject()
        same["name"] = .string("窗边")
        same["count"] = .number(.double(1.0))
        same["ok"] = .bool(false)
        let renamed = JSONObject()
        renamed["name"] = .string("今日日晒")
        let empty = JSONObject()

        XCTAssertTrue(PageParams.matches(data, same))
        XCTAssertTrue(PageParams.matches(data, empty))
        XCTAssertTrue(PageParams.matches(data, nil))
        XCTAssertTrue(!PageParams.matches(data, renamed))
        XCTAssertTrue(!PageParams.matches(nil, same))
    }
}
