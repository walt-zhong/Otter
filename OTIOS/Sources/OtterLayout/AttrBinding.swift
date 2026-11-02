import Foundation
import OtterCore

/// Evaluated attribute bag. Mirrors `ViewAttr.bind` plus each view's `applyOwn`.
struct BoundAttrs {
    var fields: [String: String]
    var scroll: Bool
    var glass: Bool
    var listItems: [[String: Any]]
}

func bindAttributes(
    viewName: String,
    attrs: [String: String],
    data: [String: Any],
    expression: (Any, Any?) -> Any?
) -> BoundAttrs {
    var fields: [String: String] = [:]
    for (name, raw) in attrs {
        if viewName == TemplateKey.OT_LIST && name == TemplateKey.ATTR_DATA {
            continue
        }
        if UnevaluatedKeys.names.contains(name) {
            fields[name] = raw
        } else {
            fields[name] = extractExpValue(raw, data: data, expression: expression)
        }
    }

    var listItems: [[String: Any]] = []
    if viewName == TemplateKey.OT_LIST, let raw = attrs[TemplateKey.ATTR_DATA] {
        let resolved = expression(raw, data)
        if let resolved, !(resolved is NSNull), let items = listItemsFromExpression(resolved) {
            listItems = items
            fields[TemplateKey.ATTR_DATA] = jsonString(items) ?? jsonString(resolved) ?? raw
        } else {
            let stringValue = stringifyResult(resolved, fallback: raw)
            fields[TemplateKey.ATTR_DATA] = stringValue
            listItems = parseListJSON(stringValue) ?? []
        }
    }

    applyAttrDefaults(viewName: viewName, fields: &fields)
    let scroll = viewName == TemplateKey.COLUMN && fields[TemplateKey.ATTR_SCROLL] == "true"
    let glass = fields[TemplateKey.ATTR_GLASS_STYLE] != nil
    return BoundAttrs(fields: fields, scroll: scroll, glass: glass, listItems: listItems)
}

/// `ExpressionWrapper.getResult`: a null result for a string expression is the
/// original text. `extractExpValue` then calls `toString()` on that result.
func extractExpValue(
    _ raw: String,
    data: Any?,
    expression: (Any, Any?) -> Any?
) -> String {
    stringifyResult(expression(raw, data), fallback: raw)
}

func applyAttrDefaults(viewName: String, fields: inout [String: String]) {
    if fields[TemplateKey.ATTR_WIDTH] == nil {
        fields[TemplateKey.ATTR_WIDTH] = "0"
    }
    if fields[TemplateKey.ATTR_HEIGHT] == nil {
        fields[TemplateKey.ATTR_HEIGHT] = "0"
    }

    switch viewName {
    case TemplateKey.TEXT:
        fields[TemplateKey.ATTR_TEXT] = fields[TemplateKey.ATTR_TEXT] ?? ""
        fields[TemplateKey.ATTR_TEXT_COLOR] = fields[TemplateKey.ATTR_TEXT_COLOR] ?? "#000000"
        fields[TemplateKey.ATTR_TEXT_SIZE] = fields[TemplateKey.ATTR_TEXT_SIZE] ?? "12px"
        fields[TemplateKey.ATTR_ELLIPSIS] = fields[TemplateKey.ATTR_ELLIPSIS] == "true" ? "true" : "false"
    case TemplateKey.IMAGE:
        fields[TemplateKey.ATTR_SRC] = fields[TemplateKey.ATTR_SRC] ?? ""
        let fit = fields[TemplateKey.ATTR_IMAGE_FIT] ?? ""
        fields[TemplateKey.ATTR_IMAGE_FIT] = fit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "cover" : fit
    case TemplateKey.INPUT:
        fields[TemplateKey.ATTR_TEXT] = fields[TemplateKey.ATTR_TEXT] ?? ""
        fields[TemplateKey.ATTR_HINT] = fields[TemplateKey.ATTR_HINT] ?? ""
        fields[TemplateKey.ATTR_HINT_COLOR] = fields[TemplateKey.ATTR_HINT_COLOR] ?? "#8A8178"
        fields[TemplateKey.ATTR_TEXT_COLOR] = fields[TemplateKey.ATTR_TEXT_COLOR] ?? "#1F1A17"
        fields[TemplateKey.ATTR_TEXT_SIZE] = fields[TemplateKey.ATTR_TEXT_SIZE] ?? "14px"
        fields[TemplateKey.ATTR_INPUT_TYPE] = fields[TemplateKey.ATTR_INPUT_TYPE] ?? "text"
        fields[TemplateKey.ATTR_LINES] = positiveIntString(fields[TemplateKey.ATTR_LINES]) ?? "1"
    case TemplateKey.CHECKBOX, TemplateKey.RADIO, TemplateKey.SWITCH:
        fields[TemplateKey.ATTR_TEXT] = fields[TemplateKey.ATTR_TEXT] ?? ""
        fields[TemplateKey.ATTR_CHECKED] = fields[TemplateKey.ATTR_CHECKED] ?? "false"
        fields[TemplateKey.ATTR_TINT] = fields[TemplateKey.ATTR_TINT] ?? "#1F6F6A"
        fields[TemplateKey.ATTR_TEXT_COLOR] = fields[TemplateKey.ATTR_TEXT_COLOR] ?? "#1F1A17"
        fields[TemplateKey.ATTR_TEXT_SIZE] = fields[TemplateKey.ATTR_TEXT_SIZE] ?? "14px"
        if viewName == TemplateKey.RADIO {
            fields[TemplateKey.ATTR_GROUP] = fields[TemplateKey.ATTR_GROUP] ?? ""
        }
    case TemplateKey.PROGRESS:
        fields[TemplateKey.ATTR_TRAIL_COLOR] = fields[TemplateKey.ATTR_TRAIL_COLOR] ?? "red"
        fields[TemplateKey.ATTR_STROKE_COLOR] = fields[TemplateKey.ATTR_STROKE_COLOR] ?? "gray"
        fields[TemplateKey.ATTR_VALUE_MIN] = fields[TemplateKey.ATTR_VALUE_MIN] ?? "0"
        fields[TemplateKey.ATTR_VALUE_MAX] = fields[TemplateKey.ATTR_VALUE_MAX] ?? "1"
        fields[TemplateKey.ATTR_ANIMATE_ENABLE] = fields[TemplateKey.ATTR_ANIMATE_ENABLE] == "true" ? "true" : "false"
    case TemplateKey.OT_LIST:
        if fields[TemplateKey.ATTR_LIST_DIRECTION] == nil {
            fields[TemplateKey.ATTR_LIST_DIRECTION] = "vertical"
        }
    default:
        break
    }

    if let weight = fields[TemplateKey.ATTR_FONT_WEIGHT] {
        let trimmed = weight.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            fields.removeValue(forKey: TemplateKey.ATTR_FONT_WEIGHT)
        } else {
            fields[TemplateKey.ATTR_FONT_WEIGHT] = trimmed
        }
    }
    if let maxLines = fields[TemplateKey.ATTR_MAX_LINES] {
        if let normalized = positiveIntString(maxLines) {
            fields[TemplateKey.ATTR_MAX_LINES] = normalized
        } else {
            fields.removeValue(forKey: TemplateKey.ATTR_MAX_LINES)
        }
    }
    if let placeholder = fields[TemplateKey.ATTR_PLACEHOLDER],
       placeholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        fields.removeValue(forKey: TemplateKey.ATTR_PLACEHOLDER)
    }
}

private func positiveIntString(_ raw: String?) -> String? {
    guard let raw, let number = Int(raw), number > 0 else {
        return nil
    }
    return String(number)
}

private func stringifyResult(_ result: Any?, fallback: String) -> String {
    if result == nil || result is NSNull {
        return fallback
    }
    return kotlinString(result!)
}

private func listItemsFromExpression(_ value: Any) -> [[String: Any]]? {
    if let items = coerceObjectArray(value) {
        return items
    }
    if let text = jsonString(value), let items = parseListJSON(text) {
        return items
    }
    return nil
}

func parseListJSON(_ text: String) -> [[String: Any]]? {
    guard let data = text.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) else {
        return nil
    }
    return coerceObjectArray(json)
}

private func coerceObjectArray(_ value: Any) -> [[String: Any]]? {
    let elements: [Any]
    if let array = value as? [Any] {
        elements = array
    } else if let array = value as? NSArray {
        elements = array.map { $0 }
    } else {
        return nil
    }
    var items: [[String: Any]] = []
    items.reserveCapacity(elements.count)
    for element in elements {
        guard let object = asDictionary(element) else {
            return nil
        }
        items.append(object)
    }
    return items
}

private func asDictionary(_ value: Any) -> [String: Any]? {
    if let dict = value as? [String: Any] {
        return dict
    }
    guard let dict = value as? NSDictionary else {
        return nil
    }
    var result: [String: Any] = [:]
    for (key, item) in dict {
        guard let key = key as? String else {
            return nil
        }
        result[key] = item
    }
    return result
}

private func jsonString(_ value: Any) -> String? {
    guard JSONSerialization.isValidJSONObject(value),
          let data = try? JSONSerialization.data(withJSONObject: value),
          let text = String(data: data, encoding: .utf8) else {
        return nil
    }
    return text
}

private func kotlinString(_ value: Any) -> String {
    if value is NSNull {
        return "null"
    }
    if let text = value as? String {
        return text
    }
    if let dict = value as? [String: Any], let json = jsonString(dict) {
        return json
    }
    if let array = value as? [Any], let json = jsonString(array) {
        return json
    }
    if let number = value as? NSNumber {
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return number.boolValue ? "true" : "false"
        }
        let type = String(cString: number.objCType)
        switch type {
        case "f", "d":
            return String(number.doubleValue)
        default:
            return number.stringValue
        }
    }
    if let flag = value as? Bool {
        return flag ? "true" : "false"
    }
    if let number = value as? Int {
        return String(number)
    }
    if let number = value as? Int64 {
        return String(number)
    }
    if let number = value as? Double {
        return String(number)
    }
    if let number = value as? Float {
        return String(number)
    }
    return String(describing: value)
}
