public struct PageRoute: Equatable {
    public let template: String
    public let data: String?

    public init(template: String, data: String?) {
        self.template = template
        self.data = data
    }
}

public struct PageRouteTable: Equatable {
    public let start: String
    public let pages: [String: PageRoute]

    public init(start: String, pages: [String: PageRoute]) {
        self.start = start
        self.pages = pages
    }
}

public enum PageRouteParser {
    public static func parse(_ json: String) throws -> PageRouteTable {
        let root = try JSONReader.rootObject(
            from: json,
            invalidPrefix: "路由不是合法 JSON：",
            notObject: "路由必须是 JSON 对象"
        )
        try JSONReader.requireKeys(
            root,
            "$",
            allowed: ["start", "pages"],
            required: ["start", "pages"]
        )
        let start = try JSONReader.requireString(root.get("start"), "$.start")
        if !JSONText.isName(start) {
            throw TemplateParseException("$.start「\(start)」必须是字母或下划线开头的标识符")
        }
        let pagesObject = try JSONReader.requireObject(root.get("pages"), "$.pages")
        if pagesObject.isEmpty {
            throw TemplateParseException("$.pages 不能是空对象")
        }
        var pages: [String: PageRoute] = [:]
        for name in pagesObject.keys {
            if !JSONText.isName(name) {
                throw TemplateParseException("$.pages 的页面名「\(name)」必须是字母或下划线开头的标识符")
            }
            let page = try JSONReader.requireObject(pagesObject.get(name), "$.pages.\(name)")
            try JSONReader.requireKeys(
                page,
                "$.pages.\(name)",
                allowed: ["template", "data"],
                required: ["template"]
            )
            let template = try JSONReader.requireString(page.get("template"), "$.pages.\(name).template")
            if template.isEmpty {
                throw TemplateParseException("$.pages.\(name).template 不能是空字符串")
            }
            let data: String?
            if page.containsKey("data") {
                let dataPath = try JSONReader.requireString(page.get("data"), "$.pages.\(name).data")
                if dataPath.isEmpty {
                    throw TemplateParseException("$.pages.\(name).data 不能是空字符串")
                }
                data = dataPath
            } else {
                data = nil
            }
            pages[name] = PageRoute(template: template, data: data)
        }
        if pages[start] == nil {
            throw TemplateParseException("$.start 引用了不存在的页面 \(start)")
        }
        return PageRouteTable(start: start, pages: pages)
    }
}
