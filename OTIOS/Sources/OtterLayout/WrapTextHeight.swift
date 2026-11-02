import CoreText
import Foundation
import OtterCore
#if canImport(UIKit)
import UIKit
#endif
#if canImport(StretchKit)
import StretchKit
#endif

/// Port of `WrapTextHeight.settle`. Runs after the first stretch pass and
/// writes measured points back into the text node's size, then lays out again.
/// `OTEngine.createNodeTree` calls this with an empty item object; list rows
/// measure later in `OTListAdapter`.
enum WrapTextHeight {
    static func settle(
        _ root: LayoutNode,
        viewport: CGSize,
        windowWidthPoints: Float,
        expression: (Any, Any?) -> Any?,
        compute: () throws -> Void
    ) throws {
        try compute()
        var guardCount = 0
        while guardCount < 4 {
            let changed = try apply(
                root,
                viewportWidth: Float(viewport.width),
                windowWidthPoints: windowWidthPoints,
                expression: expression
            )
            if !changed {
                break
            }
            try compute()
            guardCount += 1
        }
    }

    private static func apply(
        _ node: LayoutNode,
        viewportWidth: Float,
        windowWidthPoints: Float,
        expression: (Any, Any?) -> Any?
    ) throws -> Bool {
        var changed = false
        if node.viewName == TemplateKey.TEXT {
            let width = node.fields[TemplateKey.ATTR_WIDTH] ?? "0"
            let height = node.fields[TemplateKey.ATTR_HEIGHT] ?? "0"
            if isWrap(width) || isWrap(height) {
                let measured = try measure(
                    node,
                    width: width,
                    height: height,
                    viewportWidth: viewportWidth,
                    windowWidthPoints: windowWidthPoints,
                    expression: expression
                )
                if assignSize(node, measured) {
                    changed = true
                }
            }
        }
        for child in node.children {
            if try apply(
                child,
                viewportWidth: viewportWidth,
                windowWidthPoints: windowWidthPoints,
                expression: expression
            ) {
                changed = true
            }
        }
        return changed
    }

    private static func isWrap(_ value: String) -> Bool {
        value == "wrap" || value == TemplateKey.OT_WRAP_CONTENT
    }

    private static func measure(
        _ node: LayoutNode,
        width: String,
        height: String,
        viewportWidth: Float,
        windowWidthPoints: Float,
        expression: (Any, Any?) -> Any?
    ) throws -> Measured {
        let padding = try edgeSizes(
            uniform: node.fields[TemplateKey.ATTR_PADDING],
            start: node.fields[TemplateKey.ATTR_PADDING_START],
            end: node.fields[TemplateKey.ATTR_PADDING_END],
            top: node.fields[TemplateKey.ATTR_PADDING_TOP],
            bottom: node.fields[TemplateKey.ATTR_PADDING_BOTTOM],
            windowWidthPoints: windowWidthPoints
        )
        let start = padding?.start.valueInt ?? 0
        let end = padding?.end.valueInt ?? 0
        let top = padding?.top.valueInt ?? 0
        let bottom = padding?.bottom.valueInt ?? 0
        let wrapWidth = isWrap(width)
        let wrapHeight = isWrap(height)
        let laidOut = node.layout?.width
        let laidOutPositive = laidOut.flatMap { $0 > 0 ? $0 : nil }
        let maxBox: Float
        if wrapWidth || laidOutPositive == nil {
            maxBox = try maxWidthForWrap(
                node,
                viewportWidth: viewportWidth,
                windowWidthPoints: windowWidthPoints
            ) ?? laidOutPositive ?? 0
        } else {
            maxBox = laidOutPositive ?? 0
        }
        let contentWidth = max(0, javaRoundToInt(maxBox - Float(start + end)))
        // Page settle passes an empty item, same as `OTEngine.createNodeTree`.
        let text = extractExpValue(node.fields[TemplateKey.ATTR_TEXT] ?? "", data: [String: Any](), expression: expression)
        let fontSize = max(
            1,
            try OTSize.create(node.fields[TemplateKey.ATTR_TEXT_SIZE] ?? "12px", windowWidthPoints: windowWidthPoints).valueFloat
        )
        let font = systemFont(size: CGFloat(fontSize), weightName: node.fields[TemplateKey.ATTR_FONT_WEIGHT])
        let limit = lineLimit(node.fields)
        let measuredText = measureText(text, font: font, contentWidth: contentWidth, maxLines: limit)
        let widthPx: Float?
        if wrapWidth {
            let wanted = Float(ceil(Double(measuredText.lineWidth))) + Float(start + end)
            widthPx = maxBox > 0 ? min(wanted, maxBox) : wanted
        } else {
            widthPx = nil
        }
        let heightPx: Float? = wrapHeight ? Float(measuredText.layoutHeight + top + bottom) : nil
        return Measured(width: widthPx, height: heightPx)
    }

    /// `maxWidthForWrap`: parent content width, else the viewport width.
    private static func maxWidthForWrap(
        _ node: LayoutNode,
        viewportWidth: Float,
        windowWidthPoints: Float
    ) throws -> Float? {
        guard let parent = node.parent,
              let parentWidth = parent.layout?.width,
              parentWidth > 0 else {
            return viewportWidth > 0 ? viewportWidth : nil
        }
        let padding = try edgeSizes(
            uniform: parent.fields[TemplateKey.ATTR_PADDING],
            start: parent.fields[TemplateKey.ATTR_PADDING_START],
            end: parent.fields[TemplateKey.ATTR_PADDING_END],
            top: parent.fields[TemplateKey.ATTR_PADDING_TOP],
            bottom: parent.fields[TemplateKey.ATTR_PADDING_BOTTOM],
            windowWidthPoints: windowWidthPoints
        )
        let start = padding?.start.valueInt ?? 0
        let end = padding?.end.valueInt ?? 0
        let marginStart = try edgeLength(
            specific: node.fields[TemplateKey.ATTR_MARGIN_START],
            uniform: node.fields[TemplateKey.ATTR_MARGIN],
            windowWidthPoints: windowWidthPoints
        )
        let marginEnd = try edgeLength(
            specific: node.fields[TemplateKey.ATTR_MARGIN_END],
            uniform: node.fields[TemplateKey.ATTR_MARGIN],
            windowWidthPoints: windowWidthPoints
        )
        let available = parentWidth - Float(start + end + marginStart + marginEnd)
        return available > 0 ? available : nil
    }

    private static func edgeLength(
        specific: String?,
        uniform: String?,
        windowWidthPoints: Float
    ) throws -> Int {
        guard let raw = specific ?? uniform else {
            return 0
        }
        return try OTSize.create(raw, windowWidthPoints: windowWidthPoints).valueInt
    }

    private static func lineLimit(_ fields: [String: String]) -> Int {
        if let maxLines = fields[TemplateKey.ATTR_MAX_LINES], let limit = Int(maxLines), limit > 0 {
            return limit
        }
        if fields[TemplateKey.ATTR_ELLIPSIS] == "true" {
            return 1
        }
        return 0
    }

    /// `includeFontPadding = false`, line spacing 0 / multiplier 1, and
    /// fallback glyph bounds (`isFallbackLineSpacing`). Weight follows
    /// `Text.typeface`: bold, medium (500), otherwise `Typeface.NORMAL`.
    private static func measureText(
        _ text: String,
        font: CTFont,
        contentWidth: Int,
        maxLines: Int
    ) -> (lineWidth: CGFloat, layoutHeight: Int) {
        let oneLine = max(1, Int(ceil(Double(CTFontGetAscent(font) + CTFontGetDescent(font)))))
        let key = NSAttributedString.Key(rawValue: kCTFontAttributeName as String)
        let attributed = NSAttributedString(string: text, attributes: [key: font])
        if contentWidth <= 0 {
            let line = CTLineCreateWithAttributedString(attributed)
            return (lineWidth(line), oneLine)
        }
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGMutablePath()
        path.addRect(CGRect(x: 0, y: 0, width: CGFloat(contentWidth), height: 1_000_000))
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        let lines = linesInFrame(frame)
        let used = maxLines > 0 ? Array(lines.prefix(maxLines)) : lines
        if used.isEmpty {
            return (0, oneLine)
        }
        var widest: CGFloat = 0
        var total: CGFloat = 0
        for line in used {
            widest = max(widest, lineWidth(line))
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
            total += ascent + descent
        }
        let layoutHeight = max(oneLine, Int(ceil(Double(total))))
        return (widest, layoutHeight)
    }

    private static func linesInFrame(_ frame: CTFrame) -> [CTLine] {
        let raw = CTFrameGetLines(frame)
        let count = CFArrayGetCount(raw)
        var lines: [CTLine] = []
        lines.reserveCapacity(count)
        for index in 0..<count {
            guard let pointer = CFArrayGetValueAtIndex(raw, index) else {
                continue
            }
            lines.append(Unmanaged<CTLine>.fromOpaque(pointer).takeUnretainedValue())
        }
        return lines
    }

    private static func lineWidth(_ line: CTLine) -> CGFloat {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let typographic = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        return CGFloat(typographic) + CTLineGetTrailingWhitespaceWidth(line)
    }

    /// `Typeface.BOLD`, weight 500 (`UIFont.Weight.medium`), or `Typeface.NORMAL`.
    private static func systemFont(size: CGFloat, weightName: String?) -> CTFont {
        let weight: CGFloat
        switch weightName?.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "bold":
            #if canImport(UIKit)
            weight = UIFont.Weight.bold.rawValue
            #else
            weight = 0.4
            #endif
        case "medium":
            #if canImport(UIKit)
            weight = UIFont.Weight.medium.rawValue
            #else
            weight = 0.23
            #endif
        default:
            #if canImport(UIKit)
            weight = UIFont.Weight.regular.rawValue
            #else
            weight = 0
            #endif
        }
        let base = CTFontCreateUIFontForLanguage(.system, size, nil)
            ?? CTFontCreateWithName("HelveticaNeue" as CFString, size, nil)
        let family = CTFontCopyFamilyName(base)
        let descriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontFamilyNameAttribute: family,
            kCTFontTraitsAttribute: [kCTFontWeightTrait: weight]
        ] as CFDictionary)
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }

    private static func assignSize(_ node: LayoutNode, _ measured: Measured) -> Bool {
        if measured.width == nil && measured.height == nil {
            return false
        }
        let style = node.stretch.style
        let nextWidth = measured.width.map { StretchKit.Dimension.points($0) } ?? style.size.width
        let nextHeight = measured.height.map { StretchKit.Dimension.points($0) } ?? style.size.height
        if sameStretchDimension(style.size.width, nextWidth) && sameStretchDimension(style.size.height, nextHeight) {
            return false
        }
        node.stretch.style = stretchStyle(
            copying: style,
            size: Size(width: nextWidth, height: nextHeight)
        )
        return true
    }
}

private struct Measured {
    var width: Float?
    var height: Float?
}
