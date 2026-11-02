import OtterCore
import OtterExpression
import OtterLayout
import UIKit

extension TemplateKey {
    static let column = COLUMN
    static let row = ROW
    static let text = TEXT
    static let image = IMAGE
    static let spacer = SPACER
    static let list = OT_LIST
    static let progress = PROGRESS
    static let animation = ANIMATION
    static let input = INPUT
    static let checkbox = CHECKBOX
    static let radio = RADIO
    static let switcher = SWITCH
    static let id = ATTR_ID
    static let width = ATTR_WIDTH
    static let height = ATTR_HEIGHT
    static let background = ATTR_BACKGROUND
    static let onClick = ATTR_ONCLICK
    static let onChange = ATTR_ONCHANGE
    static let visible = ATTR_VISIBLE
    static let scroll = ATTR_SCROLL
    static let radius = ATTR_RADIUS
    static let leftTopRadius = ATTR_LEFT_TOP_RADIUS
    static let leftBottomRadius = ATTR_LEFT_BOTTOM_RADIUS
    static let rightTopRadius = ATTR_RIGHT_TOP_RADIUS
    static let rightBottomRadius = ATTR_RIGHT_BOTTOM_RADIUS
    static let borderColor = ATTR_BORDER_COLOR
    static let borderWidth = ATTR_BORDER_WIDTH
    static let glassStyle = ATTR_GLASS_STYLE
    static let glassTint = ATTR_GLASS_TINT
    static let glassInteractive = ATTR_GLASS_INTERACTIVE
    static let padding = ATTR_PADDING
    static let paddingStart = ATTR_PADDING_START
    static let paddingEnd = ATTR_PADDING_END
    static let paddingTop = ATTR_PADDING_TOP
    static let paddingBottom = ATTR_PADDING_BOTTOM
    static let margin = ATTR_MARGIN
    static let marginStart = ATTR_MARGIN_START
    static let marginEnd = ATTR_MARGIN_END
    static let marginTop = ATTR_MARGIN_TOP
    static let marginBottom = ATTR_MARGIN_BOTTOM
    static let minWidth = ATTR_MIN_WIDTH
    static let minHeight = ATTR_MIN_HEIGHT
    static let maxWidth = ATTR_MAX_WIDTH
    static let maxHeight = ATTR_MAX_HEIGHT
    static let aspectRatio = ATTR_ASPECT_RATIO
    static let wrapContent = OT_WRAP_CONTENT
    static let matchParent = OT_MATCH_PARENT
    static let src = ATTR_SRC
    static let fit = ATTR_IMAGE_FIT
    static let placeholder = ATTR_PLACEHOLDER
    static let textValue = ATTR_TEXT
    static let textColor = ATTR_TEXT_COLOR
    static let textSize = ATTR_TEXT_SIZE
    static let textAlign = ATTR_TEXT_ALIGN
    static let maxLines = ATTR_MAX_LINES
    static let ellipsis = ATTR_ELLIPSIS
    static let fontWeight = ATTR_FONT_WEIGHT
    static let hint = ATTR_HINT
    static let hintColor = ATTR_HINT_COLOR
    static let inputType = ATTR_INPUT_TYPE
    static let maxLength = ATTR_MAX_LENGTH
    static let lines = ATTR_LINES
    static let checked = ATTR_CHECKED
    static let tint = ATTR_TINT
    static let group = ATTR_GROUP
    static let data = ATTR_DATA
    static let listDirection = ATTR_LIST_DIRECTION
    static let horizontal = OT_HORIZONTAL
    static let vertical = OT_VERTICAL
    static let itemPadding = ATTR_ITEM_PADDING
    static let trailColor = ATTR_TRAIL_COLOR
    static let strokeColor = ATTR_STROKE_COLOR
    static let valueMin = ATTR_VALUE_MIN
    static let valueMax = ATTR_VALUE_MAX
    static let animateEnable = ATTR_ANIMATE_ENABLE
    static let animationSrc = ATTR_ANIMATION_SRC
    static let repeatCount = ATTR_ANI_REPEAT_COUNT
    static let repeatMode = ATTR_ANI_REPEAT_MODE
    static let autoPlay = ATTR_ANI_AUTO_PLAY
    static let justifyContent = FLEXBOX_ATTR_JUSTIFY_CONTENT
    static let alignItems = FLEXBOX_ATTR_ALIGN_ITEMS
    static let flexGrow = ATTR_FLEX_GROW
    static let flexWrap = ATTR_FLEX_WRAP
    static let alignSelf = ATTR_ALIGN_SELF
}

extension OTLayoutEngine {
    static func fontFor(_ fields: [String: String], scale: CGFloat) -> UIFont {
        let raw = (fields[TemplateKey.ATTR_TEXT_SIZE] ?? "12px")
            .replacingOccurrences(of: "px", with: "")
            .replacingOccurrences(of: "pt", with: "")
            .trimmingCharacters(in: .whitespaces)
        let size = (CGFloat(Double(raw) ?? 12)) * scale
        let weight: UIFont.Weight
        switch fields[TemplateKey.ATTR_FONT_WEIGHT] {
        case "bold": weight = .bold
        case "medium": weight = .medium
        default: weight = .regular
        }
        return UIFont.systemFont(ofSize: max(size, 1), weight: weight)
    }
}

enum OTMeasure {
    static func points(_ raw: String?, scale: CGFloat) -> CGFloat? {
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        if text.hasSuffix("px") || text.hasSuffix("pt") { text = String(text.dropLast(2)) }
        if text.hasSuffix("%") { return nil }
        guard let number = Double(text) else { return nil }
        return CGFloat(number) * scale
    }
}

enum OTData {
    static func parseObject(_ json: String) throws -> JSONObject {
        guard let data = json.data(using: .utf8) else {
            throw TemplateParseException("数据不是合法 JSON")
        }
        let raw: Any
        do {
            raw = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw TemplateParseException("数据不是合法 JSON")
        }
        guard let dictionary = raw as? NSDictionary else {
            throw TemplateParseException("数据必须是 JSON 对象")
        }
        return object(dictionary)
    }

    static func object(_ dictionary: NSDictionary) -> JSONObject {
        let object = JSONObject()
        for case let key as String in dictionary.allKeys {
            if let rawValue = dictionary.object(forKey: key) {
                object[key] = Self.value(from: rawValue)
            }
        }
        return object
    }

    static func value(from any: Any?) -> JSONValue {
        if any == nil || any is NSNull { return .null }
        if let text = any as? String { return .string(text) }
        if let object = any as? JSONObject { return .object(object) }
        if let array = any as? JSONArray { return .array(array) }
        if let dictionary = any as? NSDictionary { return .object(self.object(dictionary)) }
        if let array = any as? NSArray {
            let copy = JSONArray()
            for index in 0..<array.count { copy.add(value(from: array.object(at: index))) }
            return .array(copy)
        }
        if let number = any as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return .bool(number.boolValue) }
            if CFNumberIsFloatType(number) { return .number(.double(number.doubleValue)) }
            return .number(.int(Int(number.int64Value)))
        }
        if let flag = any as? Bool { return .bool(flag) }
        return .null
    }

    static func foundation(_ object: JSONObject?) -> [String: Any] {
        guard let object else { return [:] }
        var result: [String: Any] = [:]
        for key in object.keys {
            result[key] = foundationValue(object.get(key)) ?? NSNull()
        }
        return result
    }

    static func foundationValue(_ value: JSONValue?) -> Any? {
        switch value {
        case .string(let text): return text
        case .bool(let flag): return flag
        case .number(let number):
            switch number {
            case .int(let value): return value
            case .double(let value): return value
            }
        case .object(let object): return foundation(object)
        case .array(let array):
            var items: [Any] = []
            for index in 0..<array.size {
                items.append(foundationValue(array.get(index)) ?? NSNull())
            }
            return items
        case .null, nil:
            return nil
        }
    }

    static func text(_ object: JSONObject) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: foundation(object)),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return text
    }

    static func display(_ value: Any?) -> String {
        if value == nil || value is NSNull { return "null" }
        if let text = value as? String { return text }
        if let flag = value as? Bool { return flag ? "true" : "false" }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue ? "true" : "false" }
            return number.stringValue
        }
        if let number = value as? Int { return String(number) }
        if let number = value as? Double { return String(number) }
        return ""
    }

    static func boolText(_ value: Any?) -> Bool {
        if let flag = value as? Bool { return flag }
        if let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue }
        return display(value) == "true"
    }

    static func evaluate(_ raw: JSONObject, _ scope: JSONObject?) -> JSONObject {
        let data = foundation(scope)
        return PageParams.evaluate(raw) { expression in
            value(from: ExpressionEngine.shared.result(expression: expression, data: data))
        }
    }

    static func scope(_ page: JSONObject?, _ item: JSONObject?) -> JSONObject {
        PageParams.merge(page, item) ?? JSONObject()
    }

    static func listArray(_ expression: String, _ data: JSONObject?) -> JSONArray {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("$") {
            let path = String(trimmed.dropFirst())
            if !path.contains("$"), let array = lookup(path, data)?.jsonArray {
                return array
            }
        }
        let result = ExpressionEngine.shared.result(expression: expression, data: foundation(data))
        if case .array(let array) = value(from: result) { return array }
        return JSONArray()
    }

    static func lookup(_ path: String, _ data: JSONObject?) -> JSONValue? {
        guard let data else { return nil }
        let parts = path.split(separator: ".").map(String.init)
        var current: JSONValue = .object(data)
        for part in parts {
            guard let object = current.jsonObject else { return nil }
            current = object.get(part) ?? .null
        }
        return current
    }
}

enum OTLayoutCall {
    static func layout(root: ParsedNode, data: JSONObject?, viewport: CGSize, windowWidth: CGFloat) throws -> OTLaidOutNode {
        try OTLayoutEngine.layout(OTLayoutInput(
            viewport: viewport,
            windowWidth: windowWidth,
            root: root,
            data: OTData.foundation(data),
            expression: { expression, source in
                ExpressionEngine.shared.result(expression: expression, data: source)
            }
        ))
    }
}

enum OTColorParser {
    static func color(_ raw: String?) -> UIColor? {
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        if text.contains("%") {
            let parts = text.split(separator: " ")
            if parts.count == 2 { text = String(parts[0]) }
        }
        if text.lowercased() == "transparent" { return .clear }
        if text.hasPrefix("#") {
            var hex = String(text.dropFirst())
            if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
            if hex.count == 8 {
                let rgb = hex.prefix(6)
                let alpha = hex.suffix(2)
                hex = String(alpha + rgb)
            }
            var value: UInt64 = 0
            guard Scanner(string: hex).scanHexInt64(&value) else { return nil }
            if hex.count == 6 {
                return UIColor(red: CGFloat((value >> 16) & 0xff) / 255, green: CGFloat((value >> 8) & 0xff) / 255, blue: CGFloat(value & 0xff) / 255, alpha: 1)
            }
            if hex.count == 8 {
                return UIColor(red: CGFloat((value >> 16) & 0xff) / 255, green: CGFloat((value >> 8) & 0xff) / 255, blue: CGFloat(value & 0xff) / 255, alpha: CGFloat((value >> 24) & 0xff) / 255)
            }
            return nil
        }
        if text.lowercased().hasPrefix("rgb") {
            let body = text.drop { $0 != "(" }.dropFirst().dropLast()
            let parts = body.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 3, let r = Double(parts[0]), let g = Double(parts[1]), let b = Double(parts[2]) {
                let a = parts.count > 3 ? CGFloat(Double(parts[3]) ?? 1) : 1
                return UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: a)
            }
        }
        switch text.lowercased() {
        case "black": return .black
        case "dkgray": return UIColor(white: 0.333, alpha: 1)
        case "gray": return .gray
        case "ltgray": return UIColor(white: 0.667, alpha: 1)
        case "white": return .white
        case "red": return .red
        case "green": return UIColor(red: 0, green: 0.5, blue: 0, alpha: 1)
        case "blue": return .blue
        case "yellow": return .yellow
        case "cyan": return .cyan
        case "magenta": return .magenta
        default: return nil
        }
    }
}
