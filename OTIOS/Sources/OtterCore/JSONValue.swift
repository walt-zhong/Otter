import Foundation

public struct TemplateParseException: Error, Equatable, CustomStringConvertible, LocalizedError {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String { message }

    public var errorDescription: String? { message }
}

public enum JSONNumber: Equatable, CustomStringConvertible {
    case int(Int)
    case double(Double)

    public var intValue: Int {
        switch self {
        case .int(let value):
            return value
        case .double(let value):
            return Int(value)
        }
    }

    public var doubleValue: Double {
        switch self {
        case .int(let value):
            return Double(value)
        case .double(let value):
            return value
        }
    }

    public var description: String {
        switch self {
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(value)
        }
    }
}

@dynamicMemberLookup
public enum JSONValue: Equatable, CustomStringConvertible {
    case object(JSONObject)
    case array(JSONArray)
    case string(String)
    case number(JSONNumber)
    case bool(Bool)
    case null

    public var string: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    public var jsonObject: JSONObject? {
        if case .object(let value) = self {
            return value
        }
        return nil
    }

    public var jsonArray: JSONArray? {
        if case .array(let value) = self {
            return value
        }
        return nil
    }

    public var number: JSONNumber? {
        if case .number(let value) = self {
            return value
        }
        return nil
    }

    public subscript(dynamicMember member: String) -> JSONValue {
        guard case .object(let object) = self else {
            return .null
        }
        return object[dynamicMember: member]
    }

    public var description: String {
        switch self {
        case .object(let value):
            return value.description
        case .array(let value):
            return value.description
        case .string(let value):
            return "\"\(value)\""
        case .number(let value):
            return value.description
        case .bool(let value):
            return value ? "true" : "false"
        case .null:
            return "null"
        }
    }
}

@dynamicMemberLookup
public final class JSONObject: Equatable, CustomStringConvertible {
    private var order: [String] = []
    private var storage: [String: JSONValue] = [:]

    public init() {}

    public var size: Int { order.count }

    public var isEmpty: Bool { order.isEmpty }

    public var keys: [String] { order }

    public func containsKey(_ key: String) -> Bool {
        storage[key] != nil
    }

    public func get(_ key: String) -> JSONValue? {
        storage[key]
    }

    public func getString(_ key: String) -> String? {
        if case .string(let value) = storage[key] {
            return value
        }
        return nil
    }

    public func getJSONObject(_ key: String) -> JSONObject? {
        if case .object(let value) = storage[key] {
            return value
        }
        return nil
    }

    public func getJSONArray(_ key: String) -> JSONArray? {
        if case .array(let value) = storage[key] {
            return value
        }
        return nil
    }

    public func getBooleanValue(_ key: String) -> Bool {
        if case .bool(let value) = storage[key] {
            return value
        }
        return false
    }

    public subscript(key: String) -> JSONValue? {
        get { storage[key] }
        set {
            if let newValue {
                if storage[key] == nil {
                    order.append(key)
                }
                storage[key] = newValue
            } else {
                storage.removeValue(forKey: key)
                if let index = order.firstIndex(of: key) {
                    order.remove(at: index)
                }
            }
        }
    }

    public subscript(dynamicMember member: String) -> JSONValue {
        get { storage[member] ?? .null }
        set { self[member] = newValue }
    }

    public static func == (lhs: JSONObject, rhs: JSONObject) -> Bool {
        if lhs === rhs {
            return true
        }
        guard lhs.storage.count == rhs.storage.count else {
            return false
        }
        for (key, value) in lhs.storage {
            guard let other = rhs.storage[key], value == other else {
                return false
            }
        }
        return true
    }

    public var description: String {
        let body = order.map { key in
            "\(key): \(storage[key]?.description ?? "null")"
        }.joined(separator: ", ")
        return "{\(body)}"
    }
}

public final class JSONArray: Equatable, CustomStringConvertible {
    private var elements: [JSONValue] = []

    public init() {}

    public var size: Int { elements.count }

    public func get(_ index: Int) -> JSONValue? {
        guard elements.indices.contains(index) else {
            return nil
        }
        return elements[index]
    }

    public func getString(_ index: Int) -> String? {
        get(index)?.string
    }

    public func getJSONObject(_ index: Int) -> JSONObject? {
        get(index)?.jsonObject
    }

    public func add(_ value: JSONValue) {
        elements.append(value)
    }

    public static func == (lhs: JSONArray, rhs: JSONArray) -> Bool {
        if lhs === rhs {
            return true
        }
        return lhs.elements == rhs.elements
    }

    public var description: String {
        "[\(elements.map(\.description).joined(separator: ", "))]"
    }
}

enum JSONReader {
    static func rootObject(
        from json: String,
        invalidPrefix: String,
        notObject: String
    ) throws -> JSONObject {
        guard let data = json.data(using: .utf8) else {
            throw TemplateParseException("\(invalidPrefix)invalid UTF-8")
        }
        let raw: Any
        do {
            raw = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw TemplateParseException("\(invalidPrefix)\(error.localizedDescription)")
        }
        if raw is NSNull {
            throw TemplateParseException(notObject)
        }
        guard let dictionary = raw as? NSDictionary else {
            throw TemplateParseException("\(invalidPrefix)can not cast to JSONObject.")
        }
        return convertObject(dictionary)
    }

    static func requireObject(_ value: JSONValue?, _ path: String) throws -> JSONObject {
        guard case .object(let object) = value else {
            throw TemplateParseException("\(path) 必须是对象")
        }
        return object
    }

    static func requireArray(_ value: JSONValue?, _ path: String) throws -> JSONArray {
        guard case .array(let array) = value else {
            throw TemplateParseException("\(path) 必须是数组")
        }
        return array
    }

    static func requireString(_ value: JSONValue?, _ path: String) throws -> String {
        guard case .string(let text) = value else {
            throw TemplateParseException("\(path) 必须是字符串")
        }
        return text
    }

    static func requireKeys(
        _ node: JSONObject,
        _ path: String,
        allowed: Set<String>,
        required: [String]
    ) throws {
        for key in node.keys {
            if !allowed.contains(key) {
                throw TemplateParseException("\(path).\(key) 不是这里能写的字段")
            }
        }
        for key in required {
            if !node.containsKey(key) {
                throw TemplateParseException("\(path) 缺少 \(key)")
            }
        }
    }

    private static func convertObject(_ dictionary: NSDictionary) -> JSONObject {
        let object = JSONObject()
        for case let key as String in dictionary.allKeys {
            if let value = dictionary.object(forKey: key) {
                object[key] = convertValue(value)
            }
        }
        return object
    }

    private static func convertArray(_ array: NSArray) -> JSONArray {
        let result = JSONArray()
        for index in 0..<array.count {
            result.add(convertValue(array.object(at: index)))
        }
        return result
    }

    private static func convertValue(_ value: Any) -> JSONValue {
        if value is NSNull {
            return .null
        }
        if let text = value as? String {
            return .string(text)
        }
        if let dictionary = value as? NSDictionary {
            return .object(convertObject(dictionary))
        }
        if let array = value as? NSArray {
            return .array(convertArray(array))
        }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            if CFNumberIsFloatType(number) {
                return .number(.double(number.doubleValue))
            }
            return .number(.int(Int(number.int64Value)))
        }
        return .null
    }
}
