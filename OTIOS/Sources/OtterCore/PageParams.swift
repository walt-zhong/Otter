import Foundation

public enum PageParams {
    public static func evaluate(_ raw: JSONObject, resolve: (String) -> JSONValue?) -> JSONObject {
        guard case .object(let copy) = copyTree(.object(raw), resolve) else {
            return JSONObject()
        }
        return copy
    }

    public static func matches(_ data: JSONObject?, _ overlay: JSONObject?) -> Bool {
        if overlay == nil || overlay?.isEmpty == true {
            return true
        }
        guard let data, let overlay else {
            return false
        }
        for key in overlay.keys {
            if !sameValue(data.get(key), overlay.get(key)) {
                return false
            }
        }
        return true
    }

    public static func mergeInto(_ target: JSONObject, _ overlay: JSONObject) {
        for key in overlay.keys {
            target[key] = overlay.get(key) ?? .null
        }
    }

    public static func findItem(_ page: JSONObject?, _ item: JSONObject?) -> (String, Int)? {
        guard let page, let item else {
            return nil
        }
        for key in page.keys {
            guard case .array(let array) = page.get(key) else {
                continue
            }
            for index in 0..<array.size {
                if array.get(index)?.jsonObject === item {
                    return (key, index)
                }
            }
        }
        return nil
    }

    public static func merge(_ base: JSONObject?, _ overlay: JSONObject?) -> JSONObject? {
        if base == nil && overlay == nil {
            return nil
        }
        let result = JSONObject()
        copy(result, base)
        copy(result, overlay)
        return result
    }

    private static func copy(_ target: JSONObject, _ source: JSONObject?) {
        guard let source else {
            return
        }
        for key in source.keys {
            target[key] = source.get(key) ?? .null
        }
    }

    private static func copyTree(_ value: JSONValue?, _ resolve: (String) -> JSONValue?) -> JSONValue? {
        guard let value else {
            return nil
        }
        switch value {
        case .object(let object):
            let copy = JSONObject()
            for key in object.keys {
                copy[key] = copyTree(object.get(key), resolve) ?? .null
            }
            return .object(copy)
        case .array(let array):
            let copy = JSONArray()
            for index in 0..<array.size {
                copy.add(copyTree(array.get(index), resolve) ?? .null)
            }
            return .array(copy)
        case .string(let text):
            if text.hasPrefix("$") {
                return resolve(text) ?? value
            }
            return value
        case .number, .bool, .null:
            return value
        }
    }

    private static func sameValue(_ left: JSONValue?, _ right: JSONValue?) -> Bool {
        if isNull(left) || isNull(right) {
            return isNull(left) && isNull(right)
        }
        switch (left!, right!) {
        case (.bool(let lhs), .bool(let rhs)):
            return lhs == rhs
        case (.bool, _), (_, .bool):
            return false
        case (.number(let lhs), .number(let rhs)):
            return sameNumber(lhs, rhs)
        case (.object(let lhs), .object(let rhs)):
            if lhs.size != rhs.size {
                return false
            }
            return lhs.keys.allSatisfy { key in
                sameValue(lhs.get(key), rhs.get(key))
            }
        case (.array(let lhs), .array(let rhs)):
            if lhs.size != rhs.size {
                return false
            }
            return (0..<lhs.size).allSatisfy { index in
                sameValue(lhs.get(index), rhs.get(index))
            }
        case (.string(let lhs), .string(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }

    private static func isNull(_ value: JSONValue?) -> Bool {
        if value == nil {
            return true
        }
        if case .null = value {
            return true
        }
        return false
    }

    private static func sameNumber(_ left: JSONNumber, _ right: JSONNumber) -> Bool {
        let leftText = decimalText(left)
        let rightText = decimalText(right)
        let locale = Locale(identifier: "en_US_POSIX")
        guard let leftDecimal = Decimal(string: leftText, locale: locale),
              let rightDecimal = Decimal(string: rightText, locale: locale) else {
            return leftText == rightText
        }
        return leftDecimal == rightDecimal
    }

    private static func decimalText(_ number: JSONNumber) -> String {
        switch number {
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(value)
        }
    }
}

enum JSONText {
    static func isName(_ text: String) -> Bool {
        guard let first = text.unicodeScalars.first else {
            return false
        }
        if !isLetter(first) && first != "_" {
            return false
        }
        for scalar in text.unicodeScalars.dropFirst() {
            if !isLetter(scalar) && !isDigit(scalar) && scalar != "_" {
                return false
            }
        }
        return true
    }

    static func isHexColor(_ text: String) -> Bool {
        guard text.first == "#" else {
            return false
        }
        let hex = text.dropFirst()
        switch hex.count {
        case 3, 6, 8:
            break
        default:
            return false
        }
        for character in hex {
            switch character {
            case "0"..."9", "a"..."f", "A"..."F":
                continue
            default:
                return false
            }
        }
        return true
    }

    private static func isLetter(_ scalar: Unicode.Scalar) -> Bool {
        (scalar >= "A" && scalar <= "Z") || (scalar >= "a" && scalar <= "z")
    }

    private static func isDigit(_ scalar: Unicode.Scalar) -> Bool {
        scalar >= "0" && scalar <= "9"
    }
}
