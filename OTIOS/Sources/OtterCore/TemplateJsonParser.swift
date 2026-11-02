public struct ParsedNode {
    public let viewName: String
    public let id: String
    public let attrs: [String: String]
    public let children: [ParsedNode]
    public var item: ParsedNode? { itemStorage?.node }

    private let itemStorage: ParsedNodeStorage?

    public init(
        viewName: String,
        id: String,
        attrs: [String: String],
        children: [ParsedNode] = [],
        item: ParsedNode? = nil
    ) {
        self.viewName = viewName
        self.id = id
        self.attrs = attrs
        self.children = children
        self.itemStorage = item.map(ParsedNodeStorage.init)
    }
}

private final class ParsedNodeStorage {
    let node: ParsedNode

    init(_ node: ParsedNode) {
        self.node = node
    }
}

public struct ParsedTemplate {
    public let root: ParsedNode
    public let events: [String: JSONObject]

    public init(root: ParsedNode, events: [String: JSONObject]) {
        self.root = root
        self.events = events
    }
}

public enum TemplateJsonParser {
    public static func parse(_ json: String) throws -> ParsedTemplate {
        let root = try JSONReader.rootObject(
            from: json,
            invalidPrefix: "模版不是合法 JSON：",
            notObject: "模版必须是 JSON 对象"
        )
        try JSONReader.requireKeys(
            root,
            "$",
            allowed: ["layout", "events"],
            required: ["layout"]
        )
        let orderedEvents = try parseEvents(root.get("events"), "$.events")
        var events: [String: JSONObject] = [:]
        for (name, event) in orderedEvents {
            events[name] = event
        }
        var ids = Set<String>()
        var clicks: [String] = []
        var changes: [String] = []
        let layout = try parseNode(
            try JSONReader.requireObject(root.get("layout"), "$.layout"),
            "$.layout",
            &ids,
            &clicks,
            &changes
        )
        for name in clicks {
            if events[name] == nil {
                throw TemplateParseException("onClick 引用了不存在的事件 \(name)")
            }
        }
        for name in changes {
            if events[name] == nil {
                throw TemplateParseException("onChange 引用了不存在的事件 \(name)")
            }
        }
        for (name, event) in orderedEvents {
            guard let params = event.getJSONObject("params") else {
                continue
            }
            var targets: [String] = []
            if let id = params.getString("id") {
                targets.append(contentsOf: id.split(separator: ",", omittingEmptySubsequences: false).map(String.init))
            }
            if let from = params.getString("from") {
                targets.append(from)
            }
            for id in targets where !id.isEmpty && !ids.contains(id) {
                throw TemplateParseException("事件 \(name) 的 target「\(id)」在模版中不存在")
            }
        }
        return ParsedTemplate(root: layout, events: events)
    }

    private static let justifyValues = [
        "start": "start",
        "center": "center",
        "end": "end",
        "spaceBetween": "space-between",
        "spaceAround": "space-around",
        "spaceEvenly": "space-evenly"
    ]
    private static let alignValues = [
        "start": "start",
        "center": "center",
        "end": "end",
        "baseline": "baseline",
        "stretch": "stretch"
    ]
    private static let textAlignValues: Set<String> = ["start", "center", "end"]
    private static let alignSelfValues: Set<String> = ["start", "center", "end", "stretch"]
    private static let fontWeights: Set<String> = ["regular", "medium", "bold"]
    private static let imageFits: Set<String> = ["cover", "contain", "fill"]
    private static let keyboardValues: Set<String> = ["text", "number", "password", "email", "phone"]
    private static let gradientDirections = [
        "bottom": "to bottom",
        "top": "to top",
        "left": "to left",
        "right": "to right",
        "topLeft": "to top left",
        "topRight": "to top right",
        "bottomLeft": "to bottom left",
        "bottomRight": "to bottom right"
    ]
    private static let viewNames = [
        "column": TemplateKey.COLUMN,
        "row": TemplateKey.ROW,
        "text": TemplateKey.TEXT,
        "image": TemplateKey.IMAGE,
        "spacer": TemplateKey.SPACER,
        "list": TemplateKey.OT_LIST,
        "progress": TemplateKey.PROGRESS,
        "lottie": TemplateKey.ANIMATION,
        "input": TemplateKey.INPUT,
        "checkbox": TemplateKey.CHECKBOX,
        "radio": TemplateKey.RADIO,
        "switch": TemplateKey.SWITCH
    ]

    private static func parseEvents(_ value: JSONValue?, _ path: String) throws -> [(String, JSONObject)] {
        if isNull(value) {
            return []
        }
        let events = try JSONReader.requireObject(value, path)
        var result: [(String, JSONObject)] = []
        for name in events.keys {
            if !JSONText.isName(name) {
                throw TemplateParseException("\(path) 的事件名「\(name)」必须是字母或下划线开头的标识符")
            }
            let event = try JSONReader.requireObject(events.get(name), "\(path).\(name)")
            result.append((name, try parseEvent(name, event, "\(path).\(name)")))
        }
        return result
    }

    private static func parseEvent(_ name: String, _ event: JSONObject, _ path: String) throws -> JSONObject {
        guard case .string(let action) = event.get("action") else {
            throw TemplateParseException("\(path) 缺少 action")
        }
        switch action {
        case "toast":
            try JSONReader.requireKeys(
                event,
                path,
                allowed: ["action", "message"],
                required: ["action", "message"]
            )
            let message = try JSONReader.requireString(event.get("message"), "\(path).message")
            return jsonObject(
                ("class", .string("util")),
                ("params", .object(jsonObject(
                    ("fun", .string("showToast")),
                    ("info", .string(message))
                )))
            )
        case "setText":
            try JSONReader.requireKeys(
                event,
                path,
                allowed: ["action", "target", "value"],
                required: ["action", "target", "value"]
            )
            return viewEvent(
                key: "setText",
                target: try requireName(event.get("target"), "\(path).target"),
                value: .string(try JSONReader.requireString(event.get("value"), "\(path).value"))
            )
        case "setTextStyle":
            try JSONReader.requireKeys(
                event,
                path,
                allowed: ["action", "target", "fontSize", "color", "text"],
                required: ["action", "target"]
            )
            let style = JSONObject()
            if event.containsKey("fontSize") {
                style[TemplateKey.ATTR_TEXT_SIZE] = .string(try plainNumber(event.get("fontSize"), "\(path).fontSize"))
            }
            if event.containsKey("color") {
                style[TemplateKey.ATTR_TEXT_COLOR] = .string(try colorValue(event.get("color"), "\(path).color"))
            }
            if event.containsKey("text") {
                style[TemplateKey.ATTR_TEXT] = .string(try JSONReader.requireString(event.get("text"), "\(path).text"))
            }
            if style.isEmpty {
                throw TemplateParseException("\(path) 至少要写 fontSize、color、text 中的一个")
            }
            let attributes = JSONArray()
            attributes.add(.object(style))
            return viewEvent(
                key: "setTextStyle",
                target: try requireName(event.get("target"), "\(path).target"),
                value: .object(jsonObject(("attributes", .array(attributes))))
            )
        case "setChecked":
            try JSONReader.requireKeys(
                event,
                path,
                allowed: ["action", "target", "value"],
                required: ["action", "target", "value"]
            )
            let targets = try targetList(event.get("target"), "\(path).target")
            return viewEvent(
                key: "setChecked",
                target: targets.joined(separator: ","),
                value: .string(try checkedValue(event.get("value"), "\(path).value"))
            )
        case "append":
            return try parseAppendEvent(event, path)
        case "update":
            return try parseUpdateEvent(event, path)
        case "remove":
            return try parseRemoveEvent(event, path)
        case "open":
            return try parsePageEvent(event, path, "open")
        case "replace":
            return try parsePageEvent(event, path, "replace")
        case "popTo":
            return try parsePageEvent(event, path, "popTo")
        case "host":
            return try parseHostEvent(event, path)
        case "back":
            try JSONReader.requireKeys(
                event,
                path,
                allowed: ["action", "params"],
                required: ["action"]
            )
            let params = jsonObject(("fun", .string("back")))
            if event.containsKey("params") {
                params["params"] = .object(try parseOpenParams(event.get("params"), "\(path).params"))
            }
            return jsonObject(
                ("class", .string("nav")),
                ("params", .object(params))
            )
        default:
            throw TemplateParseException("\(path).action「\(action)」无法识别，事件 \(name) 只能是 toast、setText、setTextStyle、setChecked、append、update、remove、open、back、replace、popTo、host")
        }
    }

    private static func parseOpenParams(_ value: JSONValue?, _ path: String) throws -> JSONObject {
        guard case .object(let params) = value else {
            throw TemplateParseException("\(path) 必须是对象")
        }
        let result = JSONObject()
        for key in params.keys {
            if !JSONText.isName(key) {
                throw TemplateParseException("\(path).\(key) 不是这里能写的字段")
            }
            result[key] = try parseParamValue(params.get(key), "\(path).\(key)")
        }
        return result
    }

    private static func parseParamValue(_ value: JSONValue?, _ path: String) throws -> JSONValue {
        switch value {
        case .string, .number, .bool:
            return value!
        case .object:
            return .object(try parseOpenParams(value, path))
        case .array(let array):
            let copy = JSONArray()
            for index in 0..<array.size {
                copy.add(try parseParamValue(array.get(index), "\(path)[\(index)]"))
            }
            return .array(copy)
        default:
            throw TemplateParseException("\(path) 必须是字符串、数字、布尔、对象或数组")
        }
    }

    private static func parsePageEvent(_ event: JSONObject, _ path: String, _ funName: String) throws -> JSONObject {
        try JSONReader.requireKeys(
            event,
            path,
            allowed: ["action", "page", "params"],
            required: ["action", "page"]
        )
        let page = try JSONReader.requireString(event.get("page"), "\(path).page")
        if !page.hasPrefix("$") && !JSONText.isName(page) {
            throw TemplateParseException("\(path).page 必须是页面名或以 $ 开头")
        }
        let params = jsonObject(
            ("fun", .string(funName)),
            ("page", .string(page))
        )
        if event.containsKey("params") {
            params["params"] = .object(try parseOpenParams(event.get("params"), "\(path).params"))
        }
        return jsonObject(
            ("class", .string("nav")),
            ("params", .object(params))
        )
    }

    private static func parseHostEvent(_ event: JSONObject, _ path: String) throws -> JSONObject {
        try JSONReader.requireKeys(
            event,
            path,
            allowed: ["action", "name", "params"],
            required: ["action", "name"]
        )
        let hostName = try JSONReader.requireString(event.get("name"), "\(path).name")
        if !hostName.hasPrefix("$") && !JSONText.isName(hostName) {
            throw TemplateParseException("\(path).name 必须是标识符或以 $ 开头")
        }
        let params = jsonObject(
            ("fun", .string("host")),
            ("name", .string(hostName))
        )
        if event.containsKey("params") {
            params["params"] = .object(try parseOpenParams(event.get("params"), "\(path).params"))
        }
        return jsonObject(
            ("class", .string("nav")),
            ("params", .object(params))
        )
    }

    private static func parseAppendEvent(_ event: JSONObject, _ path: String) throws -> JSONObject {
        try JSONReader.requireKeys(
            event,
            path,
            allowed: ["action", "list", "from", "field", "data", "item", "empty"],
            required: ["action", "list", "from", "field", "data", "item"]
        )
        let params = jsonObject(
            ("fun", .string("append")),
            ("id", .string(try requireName(event.get("list"), "\(path).list"))),
            ("from", .string(try requireName(event.get("from"), "\(path).from"))),
            ("field", .string(try requireName(event.get("field"), "\(path).field"))),
            ("data", .string(try requireName(event.get("data"), "\(path).data"))),
            ("item", .object(try parseStringMap(event.get("item"), "\(path).item")))
        )
        if event.containsKey("empty") {
            params["empty"] = .string(try JSONReader.requireString(event.get("empty"), "\(path).empty"))
        }
        return jsonObject(
            ("class", .string("list")),
            ("params", .object(params))
        )
    }

    private static func parseUpdateEvent(_ event: JSONObject, _ path: String) throws -> JSONObject {
        try JSONReader.requireKeys(
            event,
            path,
            allowed: ["action", "list", "index", "item"],
            required: ["action", "list", "index", "item"]
        )
        return jsonObject(
            ("class", .string("list")),
            ("params", .object(jsonObject(
                ("fun", .string("update")),
                ("id", .string(try requireName(event.get("list"), "\(path).list"))),
                ("index", .string(try indexValue(event.get("index"), "\(path).index"))),
                ("item", .object(try parseStringMap(event.get("item"), "\(path).item")))
            )))
        )
    }

    private static func parseRemoveEvent(_ event: JSONObject, _ path: String) throws -> JSONObject {
        try JSONReader.requireKeys(
            event,
            path,
            allowed: ["action", "list", "index"],
            required: ["action", "list", "index"]
        )
        return jsonObject(
            ("class", .string("list")),
            ("params", .object(jsonObject(
                ("fun", .string("remove")),
                ("id", .string(try requireName(event.get("list"), "\(path).list"))),
                ("index", .string(try indexValue(event.get("index"), "\(path).index")))
            )))
        )
    }

    private static func parseStringMap(_ value: JSONValue?, _ path: String) throws -> JSONObject {
        let item = try JSONReader.requireObject(value, path)
        let fields = JSONObject()
        for key in item.keys {
            if !JSONText.isName(key) {
                throw TemplateParseException("\(path).\(key) 不是这里能写的字段")
            }
            fields[key] = .string(try JSONReader.requireString(item.get(key), "\(path).\(key)"))
        }
        return fields
    }

    private static func indexValue(_ value: JSONValue?, _ path: String) throws -> String {
        switch value {
        case .string(let text):
            if text.hasPrefix("$") {
                return text
            }
            throw TemplateParseException("\(path) 必须是非负整数或以 $ 开头")
        case .number:
            return try nonNegativeInt(value, path)
        default:
            throw TemplateParseException("\(path) 必须是非负整数或以 $ 开头")
        }
    }

    private static func viewEvent(key: String, target: String, value: JSONValue) -> JSONObject {
        jsonObject(
            ("class", .string("view")),
            ("params", .object(jsonObject(
                ("fun", .string("changeAttributes")),
                ("key", .string(key)),
                ("id", .string(target)),
                ("value", value)
            )))
        )
    }

    private static func parseNode(
        _ node: JSONObject,
        _ path: String,
        _ ids: inout Set<String>,
        _ clicks: inout [String],
        _ changes: inout [String]
    ) throws -> ParsedNode {
        guard case .string(let type) = node.get("type") else {
            throw TemplateParseException("\(path) 缺少 type")
        }
        guard let viewName = viewNames[type] else {
            throw TemplateParseException("\(path).type「\(type)」无法识别")
        }
        let isContainer = type == "column" || type == "row"
        var allowed: Set<String> = ["type", "id", "layout", "style", "onClick", "onChange", "visible"]
        var required = ["type", "layout"]
        switch type {
        case "column":
            allowed.insert("children")
            allowed.insert("scroll")
        case "row":
            allowed.insert("children")
        case "text":
            allowed.insert("text")
            required.append("text")
        case "image":
            allowed.insert("src")
            required.append("src")
        case "list":
            allowed.formUnion(["data", "direction", "gap", "item"])
            required.append(contentsOf: ["id", "data", "item"])
        case "progress":
            allowed.formUnion(["from", "to", "animate"])
        case "lottie":
            allowed.formUnion(["src", "repeat", "mode", "autoPlay"])
            required.append("src")
        case "input":
            allowed.formUnion(["value", "hint", "keyboard", "maxLength", "lines"])
        case "checkbox", "switch":
            allowed.formUnion(["checked", "label"])
        case "radio":
            allowed.formUnion(["checked", "label", "group"])
            required.append("group")
        default:
            break
        }
        try JSONReader.requireKeys(node, path, allowed: allowed, required: required)

        let id: String
        if node.containsKey("id") {
            id = try requireName(node.get("id"), "\(path).id")
        } else {
            id = "0"
        }
        if id != "0" {
            ids.insert(id)
        }

        var attrs: [String: String] = [:]
        if id != "0" {
            attrs[TemplateKey.ATTR_ID] = id
        }
        try parseLayout(
            try JSONReader.requireObject(node.get("layout"), "\(path).layout"),
            "\(path).layout",
            isContainer,
            &attrs
        )
        if node.containsKey("style") {
            try parseStyle(
                try JSONReader.requireObject(node.get("style"), "\(path).style"),
                "\(path).style",
                type,
                &attrs
            )
        }
        if node.containsKey("visible") {
            attrs[TemplateKey.ATTR_VISIBLE] = try checkedValue(node.get("visible"), "\(path).visible")
        }
        if node.containsKey("onClick") {
            let names = try parseNames(node.get("onClick"), "\(path).onClick")
            if names.isEmpty {
                throw TemplateParseException("\(path).onClick 不能是空数组")
            }
            clicks.append(contentsOf: names)
            attrs[TemplateKey.ATTR_ONCLICK] = names.joined(separator: ",")
        }
        if node.containsKey("onChange") {
            let names = try parseNames(node.get("onChange"), "\(path).onChange")
            if names.isEmpty {
                throw TemplateParseException("\(path).onChange 不能是空数组")
            }
            changes.append(contentsOf: names)
            attrs[TemplateKey.ATTR_ONCHANGE] = names.joined(separator: ",")
        }
        if node.containsKey("scroll") {
            attrs[TemplateKey.ATTR_SCROLL] = try boolString(node.get("scroll"), "\(path).scroll")
        }

        switch type {
        case "text":
            attrs[TemplateKey.ATTR_TEXT] = try JSONReader.requireString(node.get("text"), "\(path).text")
        case "image":
            attrs[TemplateKey.ATTR_SRC] = try JSONReader.requireString(node.get("src"), "\(path).src")
        case "list":
            try parseListFields(node, path, &attrs)
        case "progress":
            try parseProgressFields(node, path, &attrs)
        case "lottie":
            try parseLottieFields(node, path, &attrs)
        case "input":
            try parseInputFields(node, path, &attrs)
        case "checkbox", "switch":
            try parseCheckBoxFields(node, path, &attrs)
        case "radio":
            try parseRadioFields(node, path, &attrs)
        default:
            break
        }

        let children: [ParsedNode]
        if isContainer && node.containsKey("children") {
            let array = try JSONReader.requireArray(node.get("children"), "\(path).children")
            var parsed: [ParsedNode] = []
            for index in 0..<array.size {
                parsed.append(try parseNode(
                    try JSONReader.requireObject(array.get(index), "\(path).children[\(index)]"),
                    "\(path).children[\(index)]",
                    &ids,
                    &clicks,
                    &changes
                ))
            }
            children = parsed
        } else {
            children = []
        }
        let item: ParsedNode?
        if type == "list" {
            item = try parseNode(
                try JSONReader.requireObject(node.get("item"), "\(path).item"),
                "\(path).item",
                &ids,
                &clicks,
                &changes
            )
        } else {
            item = nil
        }
        return ParsedNode(viewName: viewName, id: id, attrs: attrs, children: children, item: item)
    }

    private static func parseLayout(
        _ layout: JSONObject,
        _ path: String,
        _ isContainer: Bool,
        _ attrs: inout [String: String]
    ) throws {
        var allowed: Set<String> = [
            "width", "height", "padding", "grow", "margin",
            "minWidth", "minHeight", "maxWidth", "maxHeight", "aspectRatio", "alignSelf"
        ]
        if isContainer {
            allowed.insert("justify")
            allowed.insert("align")
            allowed.insert("wrap")
        }
        try JSONReader.requireKeys(layout, path, allowed: allowed, required: ["width", "height"])
        attrs[TemplateKey.ATTR_WIDTH] = try sizeValue(layout.get("width"), "\(path).width")
        attrs[TemplateKey.ATTR_HEIGHT] = try sizeValue(layout.get("height"), "\(path).height")
        if layout.containsKey("padding") {
            try parseEdges(
                layout.get("padding"),
                "\(path).padding",
                TemplateKey.ATTR_PADDING,
                TemplateKey.ATTR_PADDING_START,
                TemplateKey.ATTR_PADDING_END,
                TemplateKey.ATTR_PADDING_TOP,
                TemplateKey.ATTR_PADDING_BOTTOM,
                &attrs
            )
        }
        if layout.containsKey("margin") {
            try parseEdges(
                layout.get("margin"),
                "\(path).margin",
                TemplateKey.ATTR_MARGIN,
                TemplateKey.ATTR_MARGIN_START,
                TemplateKey.ATTR_MARGIN_END,
                TemplateKey.ATTR_MARGIN_TOP,
                TemplateKey.ATTR_MARGIN_BOTTOM,
                &attrs
            )
        }
        try putSize(layout, "minWidth", TemplateKey.ATTR_MIN_WIDTH, path, &attrs)
        try putSize(layout, "minHeight", TemplateKey.ATTR_MIN_HEIGHT, path, &attrs)
        try putSize(layout, "maxWidth", TemplateKey.ATTR_MAX_WIDTH, path, &attrs)
        try putSize(layout, "maxHeight", TemplateKey.ATTR_MAX_HEIGHT, path, &attrs)
        if layout.containsKey("aspectRatio") {
            attrs[TemplateKey.ATTR_ASPECT_RATIO] = try positiveNumber(layout.get("aspectRatio"), "\(path).aspectRatio")
        }
        if layout.containsKey("alignSelf") {
            let alignSelf = try JSONReader.requireString(layout.get("alignSelf"), "\(path).alignSelf")
            if !alignSelfValues.contains(alignSelf) {
                throw TemplateParseException("\(path).alignSelf 只能是 start、center、end、stretch")
            }
            attrs[TemplateKey.ATTR_ALIGN_SELF] = alignSelf
        }
        if layout.containsKey("grow") {
            attrs[TemplateKey.ATTR_FLEX_GROW] = try plainNumber(layout.get("grow"), "\(path).grow")
        }
        if layout.containsKey("wrap") {
            let wrap = try boolString(layout.get("wrap"), "\(path).wrap")
            attrs[TemplateKey.ATTR_FLEX_WRAP] = wrap == "true" ? "wrap" : "nowrap"
        }
        if layout.containsKey("justify") {
            attrs[TemplateKey.FLEXBOX_ATTR_JUSTIFY_CONTENT] = try flexValue(
                layout.get("justify"),
                "\(path).justify",
                justifyValues
            )
        }
        if layout.containsKey("align") {
            attrs[TemplateKey.FLEXBOX_ATTR_ALIGN_ITEMS] = try enumValue(
                layout.get("align"),
                "\(path).align",
                alignValues
            )
        }
    }

    private static func putSize(
        _ layout: JSONObject,
        _ key: String,
        _ attrName: String,
        _ path: String,
        _ attrs: inout [String: String]
    ) throws {
        if layout.containsKey(key) {
            attrs[attrName] = try sizeValue(layout.get(key), "\(path).\(key)")
        }
    }

    private static func parseEdges(
        _ value: JSONValue?,
        _ path: String,
        _ uniform: String,
        _ start: String,
        _ end: String,
        _ top: String,
        _ bottom: String,
        _ attrs: inout [String: String]
    ) throws {
        switch value {
        case .number:
            attrs[uniform] = try plainNumber(value, path)
        case .object(let object):
            try JSONReader.requireKeys(
                object,
                path,
                allowed: ["start", "end", "top", "bottom"],
                required: []
            )
            if object.isEmpty {
                throw TemplateParseException("\(path) 不能是空对象")
            }
            try putSide(object, "start", start, path, &attrs)
            try putSide(object, "end", end, path, &attrs)
            try putSide(object, "top", top, path, &attrs)
            try putSide(object, "bottom", bottom, path, &attrs)
        default:
            throw TemplateParseException("\(path) 必须是数字或四边对象")
        }
    }

    private static func putSide(
        _ source: JSONObject,
        _ key: String,
        _ attrName: String,
        _ path: String,
        _ attrs: inout [String: String]
    ) throws {
        if source.containsKey(key) {
            attrs[attrName] = try plainNumber(source.get(key), "\(path).\(key)")
        }
    }

    private static func parseStyle(
        _ style: JSONObject,
        _ path: String,
        _ type: String,
        _ attrs: inout [String: String]
    ) throws {
        var allowed: Set<String> = ["background", "radius", "border"]
        if type == "column" || type == "row" || type == "spacer" {
            allowed.insert("glass")
        }
        switch type {
        case "text":
            allowed.formUnion(["color", "fontSize", "align", "maxLines", "ellipsis", "fontWeight"])
        case "image":
            allowed.formUnion(["fit", "placeholder"])
        case "input":
            allowed.formUnion(["color", "fontSize", "align", "hintColor", "lines"])
        case "checkbox", "radio", "switch":
            allowed.formUnion(["color", "fontSize", "tint"])
        case "progress":
            allowed.formUnion(["track", "bar"])
        default:
            break
        }
        try JSONReader.requireKeys(style, path, allowed: allowed, required: [])
        if style.isEmpty {
            throw TemplateParseException("\(path) 不能是空对象")
        }
        if style.containsKey("background") && style.containsKey("glass") {
            throw TemplateParseException("\(path) 不能同时写 background 和 glass")
        }
        if style.containsKey("background") {
            attrs[TemplateKey.ATTR_BACKGROUND] = try backgroundValue(style.get("background"), "\(path).background")
        }
        if style.containsKey("radius") {
            try parseRadius(style.get("radius"), "\(path).radius", &attrs)
        }
        if style.containsKey("border") {
            try parseBorder(
                try JSONReader.requireObject(style.get("border"), "\(path).border"),
                "\(path).border",
                &attrs
            )
        }
        if style.containsKey("glass") {
            try parseGlass(
                try JSONReader.requireObject(style.get("glass"), "\(path).glass"),
                "\(path).glass",
                &attrs
            )
        }
        if style.containsKey("color") {
            attrs[TemplateKey.ATTR_TEXT_COLOR] = try colorValue(style.get("color"), "\(path).color")
        }
        if style.containsKey("fontSize") {
            attrs[TemplateKey.ATTR_TEXT_SIZE] = try plainNumber(style.get("fontSize"), "\(path).fontSize")
        }
        if style.containsKey("align") {
            let align = try JSONReader.requireString(style.get("align"), "\(path).align")
            if !textAlignValues.contains(align) {
                throw TemplateParseException("\(path).align 只能是 start、center、end")
            }
            attrs[TemplateKey.ATTR_TEXT_ALIGN] = align
        }
        if style.containsKey("hintColor") {
            attrs[TemplateKey.ATTR_HINT_COLOR] = try colorValue(style.get("hintColor"), "\(path).hintColor")
        }
        if style.containsKey("tint") {
            attrs[TemplateKey.ATTR_TINT] = try colorValue(style.get("tint"), "\(path).tint")
        }
        if style.containsKey("track") {
            attrs[TemplateKey.ATTR_STROKE_COLOR] = try paintValue(style.get("track"), "\(path).track")
        }
        if style.containsKey("bar") {
            attrs[TemplateKey.ATTR_TRAIL_COLOR] = try paintValue(style.get("bar"), "\(path).bar")
        }
        if style.containsKey("maxLines") {
            attrs[TemplateKey.ATTR_MAX_LINES] = try positiveInt(style.get("maxLines"), "\(path).maxLines")
        }
        if style.containsKey("ellipsis") {
            attrs[TemplateKey.ATTR_ELLIPSIS] = try boolString(style.get("ellipsis"), "\(path).ellipsis")
        }
        if style.containsKey("fontWeight") {
            let weight = try JSONReader.requireString(style.get("fontWeight"), "\(path).fontWeight")
            if !fontWeights.contains(weight) {
                throw TemplateParseException("\(path).fontWeight 只能是 regular、medium、bold")
            }
            attrs[TemplateKey.ATTR_FONT_WEIGHT] = weight
        }
        if style.containsKey("fit") {
            let fit = try JSONReader.requireString(style.get("fit"), "\(path).fit")
            if !imageFits.contains(fit) {
                throw TemplateParseException("\(path).fit 只能是 cover、contain、fill")
            }
            attrs[TemplateKey.ATTR_IMAGE_FIT] = fit
        }
        if style.containsKey("placeholder") {
            attrs[TemplateKey.ATTR_PLACEHOLDER] = try solidColor(style.get("placeholder"), "\(path).placeholder")
        }
        if style.containsKey("lines") {
            attrs[TemplateKey.ATTR_LINES] = try positiveInt(style.get("lines"), "\(path).lines")
        }
    }

    private static func parseRadius(_ value: JSONValue?, _ path: String, _ attrs: inout [String: String]) throws {
        switch value {
        case .number:
            attrs[TemplateKey.ATTR_RADIUS] = try plainNumber(value, path)
        case .object(let object):
            try JSONReader.requireKeys(
                object,
                path,
                allowed: ["topStart", "topEnd", "bottomEnd", "bottomStart"],
                required: []
            )
            if object.isEmpty {
                throw TemplateParseException("\(path) 不能是空对象")
            }
            try putSide(object, "topStart", TemplateKey.ATTR_LEFT_TOP_RADIUS, path, &attrs)
            try putSide(object, "topEnd", TemplateKey.ATTR_RIGHT_TOP_RADIUS, path, &attrs)
            try putSide(object, "bottomEnd", TemplateKey.ATTR_RIGHT_BOTTOM_RADIUS, path, &attrs)
            try putSide(object, "bottomStart", TemplateKey.ATTR_LEFT_BOTTOM_RADIUS, path, &attrs)
        default:
            throw TemplateParseException("\(path) 必须是数字或四角对象")
        }
    }

    private static func parseGlass(_ glass: JSONObject, _ path: String, _ attrs: inout [String: String]) throws {
        try JSONReader.requireKeys(
            glass,
            path,
            allowed: ["style", "tint", "interactive"],
            required: []
        )
        let style: String
        if glass.containsKey("style") {
            style = try JSONReader.requireString(glass.get("style"), "\(path).style")
        } else {
            style = "regular"
        }
        if style != "regular" && style != "clear" {
            throw TemplateParseException("\(path).style 只能是 regular、clear")
        }
        attrs[TemplateKey.ATTR_GLASS_STYLE] = style
        if glass.containsKey("tint") {
            attrs[TemplateKey.ATTR_GLASS_TINT] = try solidColor(glass.get("tint"), "\(path).tint")
        }
        if glass.containsKey("interactive") {
            attrs[TemplateKey.ATTR_GLASS_INTERACTIVE] = try boolString(
                glass.get("interactive"),
                "\(path).interactive"
            )
        }
    }

    private static func parseBorder(_ border: JSONObject, _ path: String, _ attrs: inout [String: String]) throws {
        try JSONReader.requireKeys(border, path, allowed: ["color", "width"], required: ["color", "width"])
        attrs[TemplateKey.ATTR_BORDER_COLOR] = try colorValue(border.get("color"), "\(path).color")
        attrs[TemplateKey.ATTR_BORDER_WIDTH] = try plainNumber(border.get("width"), "\(path).width")
    }

    private static func parseListFields(_ node: JSONObject, _ path: String, _ attrs: inout [String: String]) throws {
        let data = try JSONReader.requireString(node.get("data"), "\(path).data")
        if !data.hasPrefix("$") {
            throw TemplateParseException("\(path).data 必须是 $ 开头的表达式")
        }
        attrs[TemplateKey.ATTR_DATA] = data
        let direction: String
        if node.containsKey("direction") {
            direction = try JSONReader.requireString(node.get("direction"), "\(path).direction")
        } else {
            direction = "vertical"
        }
        if direction != "horizontal" && direction != "vertical" {
            throw TemplateParseException("\(path).direction 只能是 horizontal 或 vertical")
        }
        attrs[TemplateKey.ATTR_LIST_DIRECTION] = direction
        if node.containsKey("gap") {
            attrs[TemplateKey.ATTR_ITEM_PADDING] = try plainNumber(node.get("gap"), "\(path).gap")
        }
    }

    private static func parseProgressFields(_ node: JSONObject, _ path: String, _ attrs: inout [String: String]) throws {
        if node.containsKey("from") {
            attrs[TemplateKey.ATTR_VALUE_MIN] = try fractionValue(node.get("from"), "\(path).from")
        }
        if node.containsKey("to") {
            attrs[TemplateKey.ATTR_VALUE_MAX] = try fractionValue(node.get("to"), "\(path).to")
        }
        if node.containsKey("animate") {
            attrs[TemplateKey.ATTR_ANIMATE_ENABLE] = try boolString(node.get("animate"), "\(path).animate")
        }
    }

    private static func parseInputFields(_ node: JSONObject, _ path: String, _ attrs: inout [String: String]) throws {
        if node.containsKey("value") {
            attrs[TemplateKey.ATTR_TEXT] = try JSONReader.requireString(node.get("value"), "\(path).value")
        }
        if node.containsKey("hint") {
            attrs[TemplateKey.ATTR_HINT] = try JSONReader.requireString(node.get("hint"), "\(path).hint")
        }
        let keyboard: String
        if node.containsKey("keyboard") {
            keyboard = try JSONReader.requireString(node.get("keyboard"), "\(path).keyboard")
        } else {
            keyboard = "text"
        }
        if !keyboardValues.contains(keyboard) {
            throw TemplateParseException("\(path).keyboard 只能是 text、number、password、email、phone")
        }
        attrs[TemplateKey.ATTR_INPUT_TYPE] = keyboard
        if node.containsKey("maxLength") {
            attrs[TemplateKey.ATTR_MAX_LENGTH] = try nonNegativeInt(node.get("maxLength"), "\(path).maxLength")
        }
        if node.containsKey("lines") {
            attrs[TemplateKey.ATTR_LINES] = try positiveInt(node.get("lines"), "\(path).lines")
        }
    }

    private static func parseCheckBoxFields(_ node: JSONObject, _ path: String, _ attrs: inout [String: String]) throws {
        if node.containsKey("checked") {
            attrs[TemplateKey.ATTR_CHECKED] = try checkedValue(node.get("checked"), "\(path).checked")
        } else {
            attrs[TemplateKey.ATTR_CHECKED] = "false"
        }
        if node.containsKey("label") {
            attrs[TemplateKey.ATTR_TEXT] = try JSONReader.requireString(node.get("label"), "\(path).label")
        }
    }

    private static func parseRadioFields(_ node: JSONObject, _ path: String, _ attrs: inout [String: String]) throws {
        try parseCheckBoxFields(node, path, &attrs)
        attrs[TemplateKey.ATTR_GROUP] = try groupValue(node.get("group"), "\(path).group")
    }

    private static func parseLottieFields(_ node: JSONObject, _ path: String, _ attrs: inout [String: String]) throws {
        attrs[TemplateKey.ATTR_ANIMATION_SRC] = try JSONReader.requireString(node.get("src"), "\(path).src")
        if node.containsKey("repeat") {
            attrs[TemplateKey.ATTR_ANI_REPEAT_COUNT] = try repeatValue(node.get("repeat"), "\(path).repeat")
        } else {
            attrs[TemplateKey.ATTR_ANI_REPEAT_COUNT] = "infinite"
        }
        if node.containsKey("mode") {
            let mode = try JSONReader.requireString(node.get("mode"), "\(path).mode")
            if mode != "restart" && mode != "reverse" {
                throw TemplateParseException("\(path).mode 只能是 restart 或 reverse")
            }
            attrs[TemplateKey.ATTR_ANI_REPEAT_MODE] = mode
        } else {
            attrs[TemplateKey.ATTR_ANI_REPEAT_MODE] = "restart"
        }
        if node.containsKey("autoPlay") {
            attrs[TemplateKey.ATTR_ANI_AUTO_PLAY] = try boolString(node.get("autoPlay"), "\(path).autoPlay")
        } else {
            attrs[TemplateKey.ATTR_ANI_AUTO_PLAY] = "true"
        }
    }

    private static func parseNames(_ value: JSONValue?, _ path: String) throws -> [String] {
        let array = try JSONReader.requireArray(value, path)
        var names: [String] = []
        for index in 0..<array.size {
            names.append(try requireName(array.get(index), "\(path)[\(index)]"))
        }
        return names
    }

    private static func sizeValue(_ value: JSONValue?, _ path: String) throws -> String {
        switch value {
        case .number:
            return try plainNumber(value, path)
        case .string(let text):
            switch text {
            case "fill":
                return TemplateKey.OT_MATCH_PARENT
            case "wrap":
                return TemplateKey.OT_WRAP_CONTENT
            default:
                throw TemplateParseException("\(path) 只能是数字、fill 或 wrap")
            }
        default:
            throw TemplateParseException("\(path) 只能是数字、fill 或 wrap")
        }
    }

    private static func backgroundValue(_ value: JSONValue?, _ path: String) throws -> String {
        switch value {
        case .string(let text):
            if text.hasPrefix("res:") {
                let name = String(text.dropFirst("res:".count))
                if !JSONText.isName(name) {
                    throw TemplateParseException("\(path) 的资源名必须是字母或下划线开头")
                }
                return text
            }
            return try colorValue(value, path)
        case .object(let object):
            try JSONReader.requireKeys(
                object,
                path,
                allowed: ["direction", "colors"],
                required: ["direction", "colors"]
            )
            let direction = try enumValue(object.get("direction"), "\(path).direction", gradientDirections)
            let colors = try JSONReader.requireArray(object.get("colors"), "\(path).colors")
            if colors.size < 2 {
                throw TemplateParseException("\(path).colors 至少要有两个颜色")
            }
            var colorList: [String] = []
            for index in 0..<colors.size {
                colorList.append(try colorValue(colors.get(index), "\(path).colors[\(index)]"))
            }
            return "linear-gradient(\(direction), \(colorList.joined(separator: ", ")))"
        default:
            throw TemplateParseException("\(path) 必须是颜色或渐变对象")
        }
    }

    private static func paintValue(_ value: JSONValue?, _ path: String) throws -> String {
        if case .object = value {
            return try backgroundValue(value, path)
        }
        return try colorValue(value, path)
    }

    private static func colorValue(_ value: JSONValue?, _ path: String) throws -> String {
        let color = try JSONReader.requireString(value, path)
        if color == "transparent" || color.hasPrefix("$") || JSONText.isHexColor(color) {
            return color
        }
        throw TemplateParseException("\(path) 必须是 #RGB、#RRGGBB、#AARRGGBB、transparent，或以 $ 开头")
    }

    private static func fractionValue(_ value: JSONValue?, _ path: String) throws -> String {
        switch value {
        case .number:
            return try plainNumber(value, path)
        case .string(let text):
            if text.hasPrefix("$") || Double(text) != nil {
                return text
            }
            throw TemplateParseException("\(path) 必须是数字或以 $ 开头")
        default:
            throw TemplateParseException("\(path) 必须是数字或以 $ 开头")
        }
    }

    private static func repeatValue(_ value: JSONValue?, _ path: String) throws -> String {
        switch value {
        case .string(let text):
            if text == "infinite" {
                return text
            }
            throw TemplateParseException("\(path) 只能是 infinite 或非负整数")
        case .number:
            let number = try plainNumber(value, path)
            if number.contains(".") {
                throw TemplateParseException("\(path) 只能是 infinite 或非负整数")
            }
            return number
        default:
            throw TemplateParseException("\(path) 只能是 infinite 或非负整数")
        }
    }

    private static func enumValue(_ value: JSONValue?, _ path: String, _ mapping: [String: String]) throws -> String {
        let name = try JSONReader.requireString(value, path)
        if let mapped = mapping[name] {
            return mapped
        }
        throw TemplateParseException("\(path)「\(name)」不在允许的取值里")
    }

    private static func flexValue(_ value: JSONValue?, _ path: String, _ mapping: [String: String]) throws -> String {
        let name = try JSONReader.requireString(value, path)
        if name.hasPrefix("$") {
            return name
        }
        if let mapped = mapping[name] {
            return mapped
        }
        throw TemplateParseException("\(path)「\(name)」不在允许的取值里")
    }

    private static func targetList(_ value: JSONValue?, _ path: String) throws -> [String] {
        let names: [String]
        if case .array(let array) = value {
            var parsed: [String] = []
            for index in 0..<array.size {
                parsed.append(try requireName(array.get(index), "\(path)[\(index)]"))
            }
            names = parsed
        } else {
            names = [try requireName(value, path)]
        }
        if names.isEmpty {
            throw TemplateParseException("\(path) 不能是空数组")
        }
        return names
    }

    private static func plainNumber(_ value: JSONValue?, _ path: String) throws -> String {
        guard case .number(let number) = value else {
            throw TemplateParseException("\(path) 必须是数字")
        }
        switch number {
        case .int(let intValue):
            if intValue < 0 {
                throw TemplateParseException("\(path) 不能是负数")
            }
            return String(intValue)
        case .double(let doubleValue):
            if doubleValue < 0 {
                throw TemplateParseException("\(path) 不能是负数")
            }
            if doubleValue == 0 {
                return "0"
            }
            return stripTrailingZeros(String(doubleValue))
        }
    }

    private static func stripTrailingZeros(_ text: String) -> String {
        guard let dot = text.firstIndex(of: ".") else {
            return text
        }
        var end = text.endIndex
        while end > dot {
            let previous = text.index(before: end)
            if text[previous] != "0" {
                break
            }
            end = previous
        }
        if end > dot && text[text.index(before: end)] == "." {
            end = text.index(before: end)
        }
        let result = String(text[..<end])
        if result.isEmpty || result == "-" {
            return "0"
        }
        return result
    }

    private static func boolString(_ value: JSONValue?, _ path: String) throws -> String {
        guard case .bool(let bool) = value else {
            throw TemplateParseException("\(path) 必须是布尔值")
        }
        return bool ? "true" : "false"
    }

    private static func groupValue(_ value: JSONValue?, _ path: String) throws -> String {
        let name = try JSONReader.requireString(value, path)
        if name.hasPrefix("$") || JSONText.isName(name) {
            return name
        }
        throw TemplateParseException("\(path)「\(name)」必须是字母或下划线开头的标识符，或以 $ 开头")
    }

    private static func checkedValue(_ value: JSONValue?, _ path: String) throws -> String {
        switch value {
        case .bool(let bool):
            return bool ? "true" : "false"
        case .string(let text) where text.hasPrefix("$"):
            return text
        default:
            throw TemplateParseException("\(path) 必须是布尔值或以 $ 开头")
        }
    }

    private static func positiveNumber(_ value: JSONValue?, _ path: String) throws -> String {
        let number = try plainNumber(value, path)
        if number == "0" {
            throw TemplateParseException("\(path) 必须是正数")
        }
        return number
    }

    private static func positiveInt(_ value: JSONValue?, _ path: String) throws -> String {
        let number = try nonNegativeInt(value, path)
        if number == "0" {
            throw TemplateParseException("\(path) 必须是正整数")
        }
        return number
    }

    private static func solidColor(_ value: JSONValue?, _ path: String) throws -> String {
        if case .object = value {
            throw TemplateParseException("\(path) 必须是颜色，不能是渐变")
        }
        return try colorValue(value, path)
    }

    private static func nonNegativeInt(_ value: JSONValue?, _ path: String) throws -> String {
        let number = try plainNumber(value, path)
        if number.contains(".") {
            throw TemplateParseException("\(path) 只能是非负整数")
        }
        return number
    }

    private static func requireName(_ value: JSONValue?, _ path: String) throws -> String {
        let name = try JSONReader.requireString(value, path)
        if !JSONText.isName(name) {
            throw TemplateParseException("\(path)「\(name)」必须是字母或下划线开头的标识符")
        }
        return name
    }

    private static func jsonObject(_ pairs: (String, JSONValue)...) -> JSONObject {
        let object = JSONObject()
        for (key, value) in pairs {
            object[key] = value
        }
        return object
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
}
