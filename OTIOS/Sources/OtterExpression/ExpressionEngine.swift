import Foundation

/// Swift entry that matches `ExpressionWrapper.getResult` and the
/// non-string branches of `OTAnalyze.getResult`.
///
/// String results come from the C++ engine. A string expression whose
/// evaluation is null is replaced with the original string
/// (`ExpressionWrapper.getResult`). Nested values inside a map or array
/// expression use `OTAnalyze.getResult` and do not get that replacement.
public final class ExpressionEngine {
    public static let shared = ExpressionEngine()

    private let bridge = OTExpressionBridge()

    public init() {}

    public func result(expression: Any, data: Any?) -> Any? {
        let evaluated = evaluate(expression, data: data)
        if let text = expression as? String, evaluated == nil {
            return text
        }
        return evaluated
    }

    private func evaluate(_ expression: Any, data: Any?) -> Any? {
        if let text = expression as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "$$" {
                return data
            }
            if trimmed.isEmpty {
                return nil
            }
            return unwrap(bridge.evaluateString(text, data: data))
        }

        // OTAnalyze.getResult returns these types unchanged.
        // Double is not a branch there, so it falls through to null.
        let dynamicType = type(of: expression)
        if dynamicType == Bool.self ||
            dynamicType == Int.self ||
            dynamicType == Int32.self ||
            dynamicType == Int64.self ||
            dynamicType == Float.self {
            return expression
        }
        if dynamicType == Double.self {
            return nil
        }

        if Mirror(reflecting: expression).displayStyle == .dictionary,
           let entries = expression as? [String: Any] {
            var object: [String: Any] = [:]
            object.reserveCapacity(entries.count)
            for (key, value) in entries {
                object[key] = evaluate(value, data: data) ?? NSNull()
            }
            return object
        }

        if Mirror(reflecting: expression).displayStyle == .collection,
           let list = expression as? [Any] {
            return list.map { evaluate($0, data: data) ?? NSNull() }
        }

        if let dictionary = expression as? NSDictionary {
            var object: [String: Any] = [:]
            object.reserveCapacity(dictionary.count)
            for case let key as String in dictionary.allKeys {
                let value = dictionary.object(forKey: key) as Any
                object[key] = evaluate(value, data: data) ?? NSNull()
            }
            return object
        }

        if let list = expression as? NSArray {
            var object: [Any] = []
            object.reserveCapacity(list.count)
            for value in list {
                object.append(evaluate(value, data: data) ?? NSNull())
            }
            return object
        }

        if Mirror(reflecting: expression).displayStyle == .class,
           let number = expression as? NSNumber {
            return passthroughNumber(number)
        }

        return nil
    }

    /// NSNumber standing in for a Kotlin Int, Long, Float, or Boolean
    /// expression literal. A double NSNumber matches the Double `else`
    /// branch and is null.
    private func passthroughNumber(_ number: NSNumber) -> Any? {
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return number.boolValue
        }
        let encoding = String(cString: number.objCType)
        switch encoding {
        case "f":
            return number.floatValue
        case "i":
            return Int(number.int32Value)
        case "q", "l":
            return number.int64Value
        default:
            return nil
        }
    }

    private func unwrap(_ box: OTEvalBox?) -> Any? {
        guard let box else {
            return nil
        }
        switch box.kind {
        case .bool:
            return box.boolValue
        case .long:
            return box.longValue
        case .float:
            return box.floatValue
        case .string:
            return (box.objectValue as? String) ?? ""
        case .array, .map:
            return box.objectValue
        @unknown default:
            return nil
        }
    }
}
