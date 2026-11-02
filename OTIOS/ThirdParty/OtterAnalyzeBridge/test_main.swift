import Foundation

private var failures = 0

private func describe(_ value: Any?) -> String {
    guard let value else {
        return "nil"
    }
    return "\(type(of: value)): \(value)"
}

private func expect(_ condition: Bool, _ message: String) {
    if condition {
        print("PASS \(message)")
    } else {
        failures += 1
        print("FAIL \(message)")
    }
}

private func expectEqual<T: Equatable>(_ actual: Any?, _ expected: T, _ message: String) {
    if let actual = actual as? T, actual == expected {
        print("PASS \(message)")
    } else {
        failures += 1
        print("FAIL \(message) actual=\(describe(actual)) expected=\(T.self) \(expected)")
    }
}

@main
enum ExpressionTests {
    static func main() {
        run()
        if failures == 0 {
            print("ALL PASSED")
            exit(0)
        }
        print("\(failures) FAILED")
        exit(1)
    }
}

private func run() {
let engine = ExpressionEngine.shared

let map = NSMutableDictionary()
let array = NSMutableArray()
let inner = NSMutableDictionary()
inner["map"] = map
inner["array"] = array
inner["items"] = ["x", "y", "z"]

let data = NSMutableDictionary()
data["a"] = NSNumber(value: Int32(2))
data["eight"] = NSNumber(value: Float(8))
data["title"] = "otter"
data["data"] = inner

expectEqual(engine.result(expression: "$a + 1", data: data), Int64(3), "$a + 1 == Int64(3)")
expectEqual(engine.result(expression: "10000+1", data: data), Int64(10001), "10000+1 == Int64(10001)")
expectEqual(engine.result(expression: "10.000", data: data), Float(10), "10.000 == Float(10)")
expectEqual(engine.result(expression: "$eight+2", data: data), Float(10), "$eight+2 == Float(10)")

expectEqual(engine.result(expression: "env('isiOS')", data: nil), true, "env('isiOS')")
expectEqual(engine.result(expression: "env('isAndroid')", data: nil), false, "env('isAndroid')")
expectEqual(engine.result(expression: "env('IsIOS')", data: nil), true, "env('IsIOS') case")
expectEqual(engine.result(expression: "env('ISANDROID')", data: nil), false, "env('ISANDROID') case")

expectEqual(engine.result(expression: "size('1234')", data: data), Float(4), "size('1234')")
expectEqual(engine.result(expression: "size($title)", data: data), Float(5), "size($title)")
expectEqual(engine.result(expression: "size($data.array)", data: data), Float(0), "size(empty array)")
expectEqual(engine.result(expression: "size($data.items)", data: data), Float(3), "size(3-array)")
expectEqual(engine.result(expression: "size($data.map)", data: data), Float(0), "size(empty map)")
expectEqual(engine.result(expression: "size(null)", data: data), Float(0), "size(null)")
expectEqual(engine.result(expression: "size('1234')+1", data: data), Float(5), "size('1234')+1")

expectEqual(engine.result(expression: "$title", data: data), "otter", "$title")
expect(engine.result(expression: "$data.map", data: data) as AnyObject === map, "same map instance")
expect(engine.result(expression: "$data.array", data: data) as AnyObject === array, "same array instance")
expectEqual(engine.result(expression: "$data.items[1]", data: data), "y", "path items[1]")

// ExpressionWrapper.getResult: a string whose value is null is returned unchanged.
expectEqual(engine.result(expression: "1 + abc", data: data), "1 + abc", "failed expression keeps source string")
expectEqual(engine.result(expression: "env('testWrong')", data: nil), "env('testWrong')", "unknown env keeps source string")
expectEqual(engine.result(expression: "$missing", data: data), "$missing", "missing field keeps expression")
expectEqual(engine.result(expression: "$data.stringEmpty", data: data), "$data.stringEmpty", "missing nested field")
expectEqual(engine.result(expression: "null", data: data), "null", "null literal string fallback")
expectEqual(engine.result(expression: "", data: data), "", "empty string fallback")
expectEqual(engine.result(expression: "$$", data: nil), "$$", "$$ with nil data")
expect(engine.result(expression: "$$", data: data) as AnyObject === data, "$$ returns source")

expectEqual(engine.result(expression: "false ? 1 : 0", data: data), Int64(0), "long zero is not null")
expectEqual(engine.result(expression: "true", data: data), true, "true")
expectEqual(engine.result(expression: "false", data: data), false, "false")
expectEqual(engine.result(expression: "''", data: data), "", "empty quoted string")
expectEqual(engine.result(expression: "'ab'+'cd'", data: data), "abcd", "string concat")

let swiftData: [String: Any] = ["a": 2]
expectEqual(engine.result(expression: "$a + 1", data: swiftData), Int64(3), "swift dict $a + 1")

let swiftFlag: [String: Any] = ["flag": true]
expectEqual(engine.result(expression: "$flag", data: swiftFlag), true, "swift bool field")

expectEqual(engine.result(expression: 7, data: nil), 7, "Int passthrough")
expectEqual(engine.result(expression: Int64(9), data: nil), Int64(9), "Int64 passthrough")
expectEqual(engine.result(expression: Float(1.5), data: nil), Float(1.5), "Float passthrough")
expect(engine.result(expression: Double(1.5), data: nil) == nil, "Double expression is null")

let nested = engine.result(expression: ["k": "$missing", "n": "1+1"], data: data) as? [String: Any]
expect(nested?["k"] is NSNull, "nested missing field stays null")
expect((nested?["n"] as? Int64) == 2, "nested 1+1 == Int64(2) actual=\(describe(nested?["n"]))")

let doubleField: [String: Any] = ["d": Double(8.5)]
expectEqual(engine.result(expression: "$d", data: doubleField), Float(8.5), "Double field narrows to Float")
}
