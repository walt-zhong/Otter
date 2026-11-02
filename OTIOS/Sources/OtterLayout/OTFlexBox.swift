import Foundation
import OtterCore
#if canImport(StretchKit)
import StretchKit
#endif

/// Port of `OTFlexBox`, `FlexBoxConvert`, and the padding/margin half of `StyleConverter`.
struct OTFlexBox {
    var display: Display = .flex
    var flexDirection: FlexDirection?
    var alignItems: AlignItems?
    var justifyContent: JustifyContent?
    var padding: EdgeSizes?
    var margin: EdgeSizes?
    var width: OTSize = .undefined
    var height: OTSize = .undefined
    var minSize: (OTSize?, OTSize?)?
    var maxSize: (OTSize?, OTSize?)?
    var flexGrow: Float = 0
    var aspectRatio: Float?
    var flexWrap: FlexWrap?
    var alignSelf: AlignSelf?

    static func create(viewName: String, fields: [String: String], windowWidthPoints: Float) throws -> OTFlexBox {
        var box = OTFlexBox()
        box.display = fields[TemplateKey.ATTR_VISIBLE] == "false" ? .none : .flex
        box.width = try OTSize.create(fields[TemplateKey.ATTR_WIDTH] ?? "0", windowWidthPoints: windowWidthPoints)
        box.height = try OTSize.create(fields[TemplateKey.ATTR_HEIGHT] ?? "0", windowWidthPoints: windowWidthPoints)
        box.padding = try edgeSizes(
            uniform: fields[TemplateKey.ATTR_PADDING],
            start: fields[TemplateKey.ATTR_PADDING_START],
            end: fields[TemplateKey.ATTR_PADDING_END],
            top: fields[TemplateKey.ATTR_PADDING_TOP],
            bottom: fields[TemplateKey.ATTR_PADDING_BOTTOM],
            windowWidthPoints: windowWidthPoints
        )
        box.margin = try edgeSizes(
            uniform: fields[TemplateKey.ATTR_MARGIN],
            start: fields[TemplateKey.ATTR_MARGIN_START],
            end: fields[TemplateKey.ATTR_MARGIN_END],
            top: fields[TemplateKey.ATTR_MARGIN_TOP],
            bottom: fields[TemplateKey.ATTR_MARGIN_BOTTOM],
            windowWidthPoints: windowWidthPoints
        )
        box.minSize = try boundSize(
            fields[TemplateKey.ATTR_MIN_WIDTH],
            fields[TemplateKey.ATTR_MIN_HEIGHT],
            windowWidthPoints: windowWidthPoints
        )
        box.maxSize = try boundSize(
            fields[TemplateKey.ATTR_MAX_WIDTH],
            fields[TemplateKey.ATTR_MAX_HEIGHT],
            windowWidthPoints: windowWidthPoints
        )
        box.flexGrow = Float(fields[TemplateKey.ATTR_FLEX_GROW] ?? "") ?? 0
        box.aspectRatio = fields[TemplateKey.ATTR_ASPECT_RATIO].flatMap(Float.init)
        box.alignSelf = fields[TemplateKey.ATTR_ALIGN_SELF].flatMap(alignSelfValue)

        // `ColumnAttr.flexDirection` is Column. `RowAttr.flexDirection` is Row.
        // Other views leave the stretch default, which is Row.
        let isContainer = viewName == TemplateKey.COLUMN || viewName == TemplateKey.ROW
        if viewName == TemplateKey.COLUMN {
            box.flexDirection = .column
        } else if viewName == TemplateKey.ROW {
            box.flexDirection = .row
        }
        if isContainer {
            box.justifyContent = fields[TemplateKey.FLEXBOX_ATTR_JUSTIFY_CONTENT].flatMap(justifyContentValue)
            box.alignItems = fields[TemplateKey.FLEXBOX_ATTR_ALIGN_ITEMS].flatMap(alignItemsValue)
            box.flexWrap = fields[TemplateKey.ATTR_FLEX_WRAP].flatMap(flexWrapValue)
        }
        return box
    }

    func makeStyle() -> Style {
        let minDimension = minSize.map { pair in
            Size<StretchKit.Dimension>(
                width: pair.0?.dimension ?? .auto,
                height: pair.1?.dimension ?? .auto
            )
        }
        let maxDimension = maxSize.map { pair in
            Size<StretchKit.Dimension>(
                width: pair.0?.dimension ?? .auto,
                height: pair.1?.dimension ?? .auto
            )
        }
        return Style(
            display: display,
            flexDirection: flexDirection ?? .row,
            flexWrap: flexWrap ?? .noWrap,
            alignItems: alignItems ?? .stretch,
            alignSelf: alignSelf ?? .auto,
            justifyContent: justifyContent ?? .flexStart,
            margin: margin.map(dimensionRect) ?? undefinedRect(),
            padding: dimensionRect(padding),
            // `app.visly.stretch.Style` defaults flexShrink to 0. StretchKit
            // defaults it to 1. Otter never assigns flexShrink (`StretchNode`).
            flexGrow: flexGrow,
            flexShrink: 0,
            size: Size(width: width.dimension, height: height.dimension),
            minSize: minDimension ?? Size(width: .auto, height: .auto),
            maxSize: maxDimension ?? Size(width: .auto, height: .auto),
            aspectRatio: aspectRatio
        )
    }
}

struct EdgeSizes {
    var start: OTSize
    var end: OTSize
    var top: OTSize
    var bottom: OTSize
}

func edgeSizes(
    uniform: String?,
    start: String?,
    end: String?,
    top: String?,
    bottom: String?,
    windowWidthPoints: Float
) throws -> EdgeSizes? {
    if uniform == nil && start == nil && end == nil && top == nil && bottom == nil {
        return nil
    }
    let fallback = try uniform.map { try OTSize.create($0, windowWidthPoints: windowWidthPoints) } ?? .undefined
    return EdgeSizes(
        start: try start.map { try OTSize.create($0, windowWidthPoints: windowWidthPoints) } ?? fallback,
        end: try end.map { try OTSize.create($0, windowWidthPoints: windowWidthPoints) } ?? fallback,
        top: try top.map { try OTSize.create($0, windowWidthPoints: windowWidthPoints) } ?? fallback,
        bottom: try bottom.map { try OTSize.create($0, windowWidthPoints: windowWidthPoints) } ?? fallback
    )
}

func stretchStyle(copying style: Style, size: Size<StretchKit.Dimension>) -> Style {
    Style(
        display: style.display,
        positionType: style.positionType,
        direction: style.direction,
        flexDirection: style.flexDirection,
        flexWrap: style.flexWrap,
        overflow: style.overflow,
        alignItems: style.alignItems,
        alignSelf: style.alignSelf,
        alignContent: style.alignContent,
        justifyContent: style.justifyContent,
        position: style.position,
        margin: style.margin,
        padding: style.padding,
        border: style.border,
        flexGrow: style.flexGrow,
        flexShrink: style.flexShrink,
        flexBasis: style.flexBasis,
        size: size,
        minSize: style.minSize,
        maxSize: style.maxSize,
        aspectRatio: style.aspectRatio
    )
}

func sameStretchDimension(_ current: StretchKit.Dimension, _ next: StretchKit.Dimension) -> Bool {
    switch (current, next) {
    case (.points(let lhs), .points(let rhs)):
        return abs(lhs - rhs) < 1
    case (.percent(let lhs), .percent(let rhs)):
        return lhs == rhs
    case (.auto, .auto), (.undefined, .undefined):
        return true
    default:
        return false
    }
}

private func dimensionRect(_ edges: EdgeSizes?) -> Rect<StretchKit.Dimension> {
    Rect(
        start: edges?.start.dimension ?? .undefined,
        end: edges?.end.dimension ?? .undefined,
        top: edges?.top.dimension ?? .undefined,
        bottom: edges?.bottom.dimension ?? .undefined
    )
}

private func undefinedRect() -> Rect<StretchKit.Dimension> {
    Rect(start: .undefined, end: .undefined, top: .undefined, bottom: .undefined)
}

private func boundSize(
    _ width: String?,
    _ height: String?,
    windowWidthPoints: Float
) throws -> (OTSize?, OTSize?)? {
    if width == nil && height == nil {
        return nil
    }
    return (
        try width.map { try OTSize.create($0, windowWidthPoints: windowWidthPoints) },
        try height.map { try OTSize.create($0, windowWidthPoints: windowWidthPoints) }
    )
}

private func justifyContentValue(_ target: String) -> JustifyContent? {
    switch target {
    case "start":
        return .flexStart
    case "end":
        return .flexEnd
    case "center":
        return .center
    case "space-around":
        return .spaceAround
    case "space-between":
        return .spaceBetween
    case "space-evenly":
        return .spaceEvenly
    default:
        return nil
    }
}

private func alignItemsValue(_ target: String) -> AlignItems? {
    switch target {
    case "start":
        return .flexStart
    case "end":
        return .flexEnd
    case "center":
        return .center
    case "baseline":
        return .baseline
    case "stretch":
        return .stretch
    default:
        return nil
    }
}

private func alignSelfValue(_ target: String) -> AlignSelf? {
    switch target {
    case "start":
        return .flexStart
    case "end":
        return .flexEnd
    case "center":
        return .center
    case "stretch":
        return .stretch
    default:
        return nil
    }
}

private func flexWrapValue(_ target: String) -> FlexWrap? {
    switch target {
    case "wrap":
        return .wrap
    case "nowrap":
        return .noWrap
    default:
        return nil
    }
}
