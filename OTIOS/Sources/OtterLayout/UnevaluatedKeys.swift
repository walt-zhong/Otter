import OtterCore

/// `ViewAttr.applyCommon` keeps these raw. `ContainerAttr` stores justify,
/// align, and flexWrap without `extractExpValue`. `ColumnAttr` compares
/// `scroll` to `"true"` on the raw string.
enum UnevaluatedKeys {
    static let names: Set<String> = [
        TemplateKey.ATTR_ONCLICK,
        TemplateKey.ATTR_ONCHANGE,
        TemplateKey.ATTR_ALIGN_SELF,
        TemplateKey.FLEXBOX_ATTR_JUSTIFY_CONTENT,
        TemplateKey.FLEXBOX_ATTR_ALIGN_ITEMS,
        TemplateKey.ATTR_FLEX_WRAP,
        TemplateKey.ATTR_SCROLL
    ]
}
