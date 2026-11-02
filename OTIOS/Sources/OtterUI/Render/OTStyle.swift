import OtterCore
import OtterExpression
import UIKit

enum OTAssets {
    static var bundle: Bundle = .main

    static func text(_ path: String) throws -> String {
        guard let url = file(path) else {
            throw TemplateParseException("找不到模版 \(path)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func file(_ path: String) -> URL? {
        let manager = FileManager.default
        let roots = [
            bundle.bundleURL,
            bundle.bundleURL.appendingPathComponent("assets"),
            bundle.bundleURL.appendingPathComponent("android-res")
        ]
        for root in roots {
            let candidate = root.appendingPathComponent(path)
            if manager.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    static func image(named name: String) -> UIImage? {
        let folders = ["drawable-nodpi", "drawable", "drawable-hdpi", "drawable-xhdpi", "drawable-xxhdpi", "drawable-xxxhdpi", "mipmap-xxhdpi", "mipmap"]
        let extensions = ["png", "jpg", "jpeg", "webp"]
        let roots = [bundle.bundleURL.appendingPathComponent("android-res"), bundle.bundleURL]
        let manager = FileManager.default
        for root in roots {
            for folder in folders {
                for ext in extensions {
                    let url = root.appendingPathComponent(folder).appendingPathComponent("\(name).\(ext)")
                    if manager.fileExists(atPath: url.path), let image = UIImage(contentsOfFile: url.path) {
                        return image
                    }
                }
                let xml = root.appendingPathComponent(folder).appendingPathComponent("\(name).xml")
                if manager.fileExists(atPath: xml.path), let image = OTVectorImage.image(at: xml) {
                    return image
                }
            }
        }
        return UIImage(named: name)
    }
}

enum OTVectorImage {
    static func image(at url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8),
              text.contains("<vector") else { return nil }
        let viewport = (attr(text, "viewportWidth") ?? 24, attr(text, "viewportHeight") ?? 24)
        let size = CGSize(width: attr(text, "android:width") ?? viewport.0, height: attr(text, "android:height") ?? viewport.1)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: max(size.width, 1), height: max(size.height, 1)))
        return renderer.image { ctx in
            ctx.cgContext.scaleBy(x: size.width / viewport.0, y: size.height / viewport.1)
            for path in paths(text) {
                let bezier = OTPathData.bezier(path.data)
                if let fill = path.fill, fill != "#00000000" {
                    OTColorParser.color(fill)?.setFill()
                    bezier.fill()
                }
                if let stroke = path.stroke, path.strokeWidth > 0 {
                    OTColorParser.color(stroke)?.setStroke()
                    bezier.lineWidth = path.strokeWidth
                    bezier.lineCapStyle = path.cap
                    bezier.lineJoinStyle = path.join
                    bezier.stroke()
                }
            }
        }
    }

    private struct VectorPath {
        var data: String
        var fill: String?
        var stroke: String?
        var strokeWidth: CGFloat
        var cap: CGLineCap
        var join: CGLineJoin
    }

    private static func attr(_ text: String, _ name: String) -> CGFloat? {
        let token = "\(name)=\""
        guard let range = text.range(of: token) else { return nil }
        let rest = text[range.upperBound...]
        let raw = rest.prefix { $0 != "\"" }
        let number = raw.replacingOccurrences(of: "dp", with: "").replacingOccurrences(of: "px", with: "")
        return Double(number).map { CGFloat($0) }
    }

    private static func paths(_ text: String) -> [VectorPath] {
        var result: [VectorPath] = []
        let parts = text.components(separatedBy: "<path")
        for part in parts.dropFirst() {
            let body = part.components(separatedBy: "/>").first ?? part
            let data = stringAttr(body, "pathData") ?? ""
            let fill = stringAttr(body, "fillColor")
            let stroke = stringAttr(body, "strokeColor")
            let width = attr(body, "strokeWidth") ?? 0
            let cap: CGLineCap = (stringAttr(body, "strokeLineCap") == "round") ? .round : .butt
            let join: CGLineJoin = (stringAttr(body, "strokeLineJoin") == "round") ? .round : .miter
            result.append(VectorPath(data: data, fill: fill, stroke: stroke, strokeWidth: width, cap: cap, join: join))
        }
        return result
    }

    private static func stringAttr(_ text: String, _ name: String) -> String? {
        let token = "\(name)=\""
        guard let range = text.range(of: token) else { return nil }
        let rest = text[range.upperBound...]
        return String(rest.prefix { $0 != "\"" })
    }
}

enum OTPathData {
    static func bezier(_ data: String) -> UIBezierPath {
        let path = UIBezierPath()
        let tokens = tokenize(data)
        var index = 0
        var command: Character = "M"
        var current = CGPoint.zero
        var start = CGPoint.zero
        func number() -> CGFloat? {
            guard index < tokens.count else { return nil }
            if let value = Double(tokens[index]) {
                index += 1
                return CGFloat(value)
            }
            return nil
        }
        while index < tokens.count {
            if tokens[index].count == 1, let first = tokens[index].first, first.isLetter {
                command = first
                index += 1
            }
            let relative = command.isLowercase
            let absolute = Character(command.uppercased())
            switch absolute {
            case "M":
                guard let x = number(), let y = number() else { return path }
                current = relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                path.move(to: current)
                start = current
                command = relative ? "l" : "L"
            case "L":
                guard let x = number(), let y = number() else { return path }
                current = relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                path.addLine(to: current)
            case "H":
                guard let x = number() else { return path }
                current.x = relative ? current.x + x : x
                path.addLine(to: current)
            case "V":
                guard let y = number() else { return path }
                current.y = relative ? current.y + y : y
                path.addLine(to: current)
            case "C":
                guard let x1 = number(), let y1 = number(), let x2 = number(), let y2 = number(), let x = number(), let y = number() else { return path }
                let c1 = relative ? CGPoint(x: current.x + x1, y: current.y + y1) : CGPoint(x: x1, y: y1)
                let c2 = relative ? CGPoint(x: current.x + x2, y: current.y + y2) : CGPoint(x: x2, y: y2)
                current = relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                path.addCurve(to: current, controlPoint1: c1, controlPoint2: c2)
            case "Z":
                path.close()
                current = start
            case "A":
                guard let rx = number(), let ry = number(), number() != nil, let large = number(), let sweep = number(), let x = number(), let y = number() else { return path }
                let end = relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                addArc(path, from: current, to: end, rx: rx, ry: ry, large: large != 0, sweep: sweep != 0)
                current = end
            default:
                index += 1
            }
        }
        return path
    }

    private static func tokenize(_ data: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        func flush() {
            if !current.isEmpty { tokens.append(current); current = "" }
        }
        for character in data {
            if character.isLetter || character == "," || character.isWhitespace {
                flush()
                if character.isLetter { tokens.append(String(character)) }
            } else if character == "-" && !current.isEmpty && !current.hasSuffix("e") && !current.hasSuffix("E") {
                flush()
                current.append(character)
            } else {
                current.append(character)
            }
        }
        flush()
        return tokens
    }

    private static func addArc(_ path: UIBezierPath, from: CGPoint, to: CGPoint, rx: CGFloat, ry: CGFloat, large: Bool, sweep: Bool) {
        if rx == 0 || ry == 0 {
            path.addLine(to: to)
            return
        }
        let radius = max(rx, ry)
        let center = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        path.addQuadCurve(to: to, controlPoint: CGPoint(
            x: center.x + (sweep ? radius : -radius) * 0.15,
            y: center.y + (large ? -radius : radius) * 0.15
        ))
        if abs(from.x - to.x) < 0.01 && abs(from.y - to.y) < 0.01 {
            path.addArc(withCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        }
    }
}

enum OTChrome {
    static func scale(for view: UIView) -> CGFloat {
        OTViewMark.bind(view).scale
    }

    static func apply(view: UIView, fields: [String: String], scale: CGFloat, itemData: JSONObject?) {
        let background = eval(fields[TemplateKey.background], itemData)
        let glassStyle = fields[TemplateKey.glassStyle]
        if glassStyle != nil {
            OTGlassLayer.attach(view, fields: fields, itemData: itemData)
        } else {
            OTGlassLayer.remove(view)
            applyBackground(view, raw: background, scale: scale)
        }
        applyCorner(view, fields: fields, scale: scale)
    }

    static func eval(_ raw: String?, _ data: JSONObject?) -> String? {
        guard let raw else { return nil }
        if raw.contains("$") || raw.contains("size(") || raw.contains("env(") {
            return OTData.display(ExpressionEngine.shared.result(expression: raw, data: OTData.foundation(data)))
        }
        return raw
    }

    private static func applyBackground(_ view: UIView, raw: String?, scale: CGFloat) {
        view.layer.sublayers?.removeAll { $0.name == "otter.gradient" }
        if let raw, raw.hasPrefix("linear-gradient") {
            let layer = CAGradientLayer()
            layer.name = "otter.gradient"
            layer.frame = view.bounds
            let parsed = parseGradient(raw)
            layer.colors = parsed.colors.map { $0.cgColor }
            layer.startPoint = parsed.start
            layer.endPoint = parsed.end
            view.layer.insertSublayer(layer, at: 0)
            view.backgroundColor = .clear
            return
        }
        if let raw, raw.hasPrefix("res:") {
            let name = String(raw.dropFirst(4))
            if let column = view as? OTColumnView {
                column.showBackdrop(named: name)
            } else if let image = OTAssets.image(named: name) {
                view.layer.contents = image.cgImage
                view.layer.contentsGravity = .resizeAspectFill
            }
            return
        }
        view.layer.contents = nil
        (view as? OTColumnView)?.clearBackdrop()
        if let raw, let color = OTColorParser.color(raw) {
            view.backgroundColor = color
        } else if raw == nil {
            view.backgroundColor = .clear
        }
    }

    static func parseGradient(_ raw: String) -> (colors: [UIColor], start: CGPoint, end: CGPoint) {
        let body = raw.dropFirst("linear-gradient(".count).dropLast()
        let parts = body.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        let direction = parts.first.map { $0.trimmingCharacters(in: .whitespaces) } ?? "to bottom"
        let colorText = parts.count > 1 ? String(parts[1]) : ""
        let colors = colorText.split(separator: ",").compactMap { OTColorParser.color($0.trimmingCharacters(in: .whitespaces)) }
        let points = gradientPoints(direction)
        return (colors.isEmpty ? [.clear, .clear] : colors, points.0, points.1)
    }

    private static func gradientPoints(_ direction: String) -> (CGPoint, CGPoint) {
        switch direction {
        case "to top": return (CGPoint(x: 0.5, y: 1), CGPoint(x: 0.5, y: 0))
        case "to left": return (CGPoint(x: 1, y: 0.5), CGPoint(x: 0, y: 0.5))
        case "to right": return (CGPoint(x: 0, y: 0.5), CGPoint(x: 1, y: 0.5))
        case "to top left": return (CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 0))
        case "to top right": return (CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 0))
        case "to bottom left": return (CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1))
        case "to bottom right": return (CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1))
        default: return (CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 1))
        }
    }

    static func applyCorner(_ view: UIView, fields: [String: String], scale: CGFloat) {
        func points(_ key: String) -> CGFloat? {
            OTMeasure.points(fields[key], scale: scale)
        }
        let uniform = points(TemplateKey.radius) ?? 0
        let topLeft = points(TemplateKey.leftTopRadius) ?? uniform
        let topRight = points(TemplateKey.rightTopRadius) ?? uniform
        let bottomRight = points(TemplateKey.rightBottomRadius) ?? uniform
        let bottomLeft = points(TemplateKey.leftBottomRadius) ?? uniform
        let corners = [topLeft, topRight, bottomRight, bottomLeft]
        let borderWidth = points(TemplateKey.borderWidth) ?? 0
        let borderColor = OTColorParser.color(fields[TemplateKey.borderColor])
        let same = corners.allSatisfy { abs($0 - corners[0]) < 0.5 }
        if same && corners[0] > 0 {
            view.layer.cornerRadius = corners[0]
            view.layer.mask = nil
            view.clipsToBounds = true
        } else if corners.contains(where: { $0 > 0 }) {
            let mask = CAShapeLayer()
            mask.path = cornerPath(view.bounds, corners).cgPath
            view.layer.mask = mask
            view.clipsToBounds = true
        } else {
            view.layer.cornerRadius = 0
            view.layer.mask = nil
        }
        if borderWidth > 0, let borderColor {
            view.layer.borderWidth = borderWidth
            view.layer.borderColor = borderColor.cgColor
        } else if view.layer.borderWidth > 0 && fields[TemplateKey.borderWidth] == nil {
            view.layer.borderWidth = 0
        }
        OTViewMark.bind(view).radii = corners
    }

    static func cornerPath(_ rect: CGRect, _ radii: [CGFloat]) -> UIBezierPath {
        let path = UIBezierPath()
        let tl = radii[0], tr = radii[1], br = radii[2], bl = radii[3]
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(withCenter: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(withCenter: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: 0, endAngle: .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(withCenter: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(withCenter: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
        path.close()
        return path
    }
}

/// Visual gap versus Android `LiquidGlassDrawable`:
/// On iOS 26, `UIGlassEffect` supplies regular vs clear, tint, and interactive highlight
/// through public UIKit. It does not sample a backdrop bitmap and it does not run the
/// Android RuntimeShader's corner refraction or dispersion.
/// Before iOS 26, `UIBlurEffect` (systemThinMaterial for regular, systemUltraThinMaterial
/// for clear) plus a tint overlay is the stand-in. There is no edge refraction.
/// Corner radius clips children the way the Android view does. Glass is only the
/// background; subviews stay sharp.
enum OTGlassLayer {
    private static var key: UInt8 = 0

    static func attach(_ view: UIView, fields: [String: String], itemData: JSONObject?) {
        let effectView: UIVisualEffectView
        if let existing = objc_getAssociatedObject(view, &key) as? UIVisualEffectView {
            effectView = existing
        } else {
            effectView = UIVisualEffectView()
            effectView.isUserInteractionEnabled = false
            effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            objc_setAssociatedObject(view, &key, effectView, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            view.insertSubview(effectView, at: 0)
        }
        effectView.frame = view.bounds
        let style = fields[TemplateKey.glassStyle] ?? "regular"
        let tint = OTColorParser.color(OTChrome.eval(fields[TemplateKey.glassTint], itemData))
        let interactive = fields[TemplateKey.glassInteractive] == "true"
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect(style: style == "clear" ? .clear : .regular)
            glass.tintColor = tint
            glass.isInteractive = interactive
            effectView.effect = glass
        } else {
            let blur = UIBlurEffect(style: style == "clear" ? .systemUltraThinMaterial : .systemThinMaterial)
            effectView.effect = blur
            let overlay = effectView.contentView.viewWithTag(71) ?? UIView()
            overlay.tag = 71
            overlay.frame = effectView.bounds
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            overlay.isUserInteractionEnabled = false
            overlay.backgroundColor = tint ?? (style == "clear" ? UIColor(white: 1, alpha: 0.04) : UIColor(white: 1, alpha: 0.18))
            if overlay.superview == nil { effectView.contentView.addSubview(overlay) }
        }
        effectView.layer.cornerRadius = view.layer.cornerRadius
        effectView.clipsToBounds = true
        OTViewMark.bind(view).glassInteractive = interactive
    }

    static func remove(_ view: UIView) {
        if let effect = objc_getAssociatedObject(view, &key) as? UIView {
            effect.removeFromSuperview()
            objc_setAssociatedObject(view, &key, nil, .OBJC_ASSOCIATION_ASSIGN)
        }
    }

    static func layout(_ view: UIView) {
        guard let effect = objc_getAssociatedObject(view, &key) as? UIVisualEffectView else { return }
        effect.frame = view.bounds
        effect.layer.cornerRadius = view.layer.cornerRadius
        if let mask = view.layer.mask as? CAShapeLayer, let path = mask.path {
            let copy = CAShapeLayer()
            copy.path = path
            effect.layer.mask = copy
        }
    }
}
