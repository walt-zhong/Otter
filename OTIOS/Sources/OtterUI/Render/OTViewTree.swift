import OtterCore
import OtterLayout
import UIKit

enum OTViewTree {
    static func build(parsed: ParsedNode, laid: OTLaidOutNode, template: OTTemplateContext, itemData: JSONObject?) throws -> UIView {
        let view = try make(parsed, laid, template, itemData)
        if let container = contentHost(view) {
            for (index, child) in parsed.children.enumerated() where index < laid.children.count {
                let childView = try build(parsed: child, laid: laid.children[index], template: template, itemData: itemData)
                container.templateChildren.append(childView)
                container.addSubview(childView)
            }
            container.placeChildren()
        }
        if parsed.viewName == TemplateKey.list, let list = view as? OTListView {
            configureList(list, parsed: parsed, laid: laid, template: template)
        }
        return view
    }

    static func rebind(view: UIView, parsed: ParsedNode, laid: OTLaidOutNode, template: OTTemplateContext) throws {
        fill(view: view, parsed: parsed, laid: laid, template: template, itemData: nil)
        guard parsed.viewName != TemplateKey.list, let container = contentHost(view) else { return }
        let count = min(container.templateChildren.count, min(parsed.children.count, laid.children.count))
        for index in 0..<count {
            try rebind(view: container.templateChildren[index], parsed: parsed.children[index], laid: laid.children[index], template: template)
        }
    }

    static func applyFrames(view: UIView, laid: OTLaidOutNode) {
        OTViewMark.bind(view).otterFrame = laid.frame
        view.frame = laid.frame
        guard laid.viewName != TemplateKey.list, let container = contentHost(view) else { return }
        let count = min(container.templateChildren.count, laid.children.count)
        for index in 0..<count {
            applyFrames(view: container.templateChildren[index], laid: laid.children[index])
        }
        container.placeChildren()
    }

    private static func contentHost(_ view: UIView) -> OTAbsoluteView? {
        if let column = view as? OTColumnView, column.scrolling { return column.scrollContent }
        return view as? OTAbsoluteView
    }

    private static func make(_ parsed: ParsedNode, _ laid: OTLaidOutNode, _ template: OTTemplateContext, _ itemData: JSONObject?) throws -> UIView {
        let view: UIView
        switch parsed.viewName {
        case TemplateKey.column:
            let column = OTColumnView()
            if parsed.attrs[TemplateKey.scroll] == "true" { column.ensureScroll() }
            view = column
        case TemplateKey.row: view = OTRowView()
        case TemplateKey.text: view = OTTextView()
        case TemplateKey.image: view = OTImageView()
        case TemplateKey.spacer: view = OTSpacerView()
        case TemplateKey.list: view = OTListView()
        case TemplateKey.progress: view = OTProgressView()
        case TemplateKey.animation: view = OTLottieView()
        case TemplateKey.input:
            let lines = Int(parsed.attrs[TemplateKey.lines] ?? "1") ?? 1
            view = lines > 1 ? OTInputArea() : OTInputView()
        case TemplateKey.checkbox: view = OTCheckView()
        case TemplateKey.radio: view = OTRadioView()
        case TemplateKey.switcher: view = OTSwitchView()
        default:
            throw TemplateParseException("type「\(parsed.viewName)」无法识别")
        }
        OTViewMark.bind(view).otterFrame = laid.frame
        view.frame = laid.frame
        fill(view: view, parsed: parsed, laid: laid, template: template, itemData: itemData)
        return view
    }

    private static func fill(view: UIView, parsed: ParsedNode, laid: OTLaidOutNode, template: OTTemplateContext, itemData: JSONObject?) {
        let bind = OTViewMark.bind(view)
        bind.template = template
        bind.itemData = itemData
        bind.fields = parsed.attrs
        bind.scale = template.scale
        bind.parsed = parsed
        let scope = itemData ?? template.data
        if let id = parsed.attrs[TemplateKey.id] {
            bind.idName = id
            view.accessibilityIdentifier = id
            template.viewIds[id] = view
        }
        let visible = OTChrome.eval(parsed.attrs[TemplateKey.visible], scope) ?? "true"
        view.isHidden = visible == "false"
        OTChrome.apply(view: view, fields: parsed.attrs, scale: template.scale, itemData: scope)
        let clicks = (parsed.attrs[TemplateKey.onClick] ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        OTEvents.attachClick(view, names: clicks)
        bind.changeNames = (parsed.attrs[TemplateKey.onChange] ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        push(view: view, parsed: parsed, scope: scope, template: template)
    }

    private static func push(view: UIView, parsed: ParsedNode, scope: JSONObject?, template: OTTemplateContext) {
        let fields = parsed.attrs
        switch view {
        case let label as OTTextView:
            bindText(label, fields, scope, template.scale)
        case let image as OTImageView:
            image.fit = fields[TemplateKey.fit] ?? "cover"
            image.placeholder = OTColorParser.color(OTChrome.eval(fields[TemplateKey.placeholder], scope))
            image.load(OTChrome.eval(fields[TemplateKey.src], scope) ?? "")
        case let input as OTInputView:
            bindInput(input, fields, scope, template.scale)
        case let area as OTInputArea:
            bindArea(area, fields, scope, template.scale)
        case let box as OTCheckView:
            bindCheck(box, fields, scope, template.scale)
        case let radio as OTRadioView:
            bindRadio(radio, fields, scope, template.scale)
        case let toggle as OTSwitchView:
            bindSwitch(toggle, fields, scope, template.scale)
        case let progress as OTProgressView:
            let from = CGFloat(Double(OTChrome.eval(fields[TemplateKey.valueMin] ?? "0", scope) ?? "0") ?? 0)
            let to = CGFloat(Double(OTChrome.eval(fields[TemplateKey.valueMax] ?? "1", scope) ?? "1") ?? 1)
            progress.trackColor = OTColorParser.color(OTChrome.eval(fields[TemplateKey.strokeColor], scope)) ?? .gray
            progress.barColor = OTColorParser.color(OTChrome.eval(fields[TemplateKey.trailColor], scope)) ?? .red
            progress.bind(from: from, to: to, animate: fields[TemplateKey.animateEnable] == "true")
        case let lottie as OTLottieView:
            lottie.bind(
                src: fields[TemplateKey.animationSrc] ?? "",
                repeatCount: fields[TemplateKey.repeatCount] ?? "infinite",
                mode: fields[TemplateKey.repeatMode] ?? "restart",
                autoPlay: (fields[TemplateKey.autoPlay] ?? "true") == "true"
            )
        default:
            break
        }
    }

    private static func bindText(_ label: OTTextView, _ fields: [String: String], _ scope: JSONObject?, _ scale: CGFloat) {
        label.text = OTChrome.eval(fields[TemplateKey.textValue], scope) ?? ""
        label.textColor = OTColorParser.color(OTChrome.eval(fields[TemplateKey.textColor], scope)) ?? .black
        label.font = OTLayoutEngine.fontFor(fields, scale: scale)
        label.numberOfLines = lineLimit(fields)
        label.lineBreakMode = fields[TemplateKey.ellipsis] == "true" ? .byTruncatingTail : .byWordWrapping
        let wrap = fields[TemplateKey.height] == TemplateKey.wrapContent
        let align = fields[TemplateKey.textAlign]
        switch align {
        case "center": label.textAlignment = .center
        case "end": label.textAlignment = .right
        case "start": label.textAlignment = .left
        default: label.textAlignment = .left
        }
        if wrap || align == nil {
            label.baselineAdjustment = .alignBaselines
        }
        label.textInset = padding(fields, scale)
    }

    private static func lineLimit(_ fields: [String: String]) -> Int {
        if let raw = fields[TemplateKey.maxLines], let value = Int(raw), value > 0 { return value }
        if fields[TemplateKey.ellipsis] == "true" { return 1 }
        return 0
    }

    private static func bindInput(_ input: OTInputView, _ fields: [String: String], _ scope: JSONObject?, _ scale: CGFloat) {
        input.suppressChange = true
        input.font = OTLayoutEngine.fontFor(fields, scale: scale)
        input.textColor = OTColorParser.color(OTChrome.eval(fields[TemplateKey.textColor], scope)) ?? OTColorParser.color("#1F1A17")
        input.textValue = OTChrome.eval(fields[TemplateKey.textValue], scope) ?? ""
        input.placeholder = OTChrome.eval(fields[TemplateKey.hint], scope)
        if let hint = input.placeholder, let color = OTColorParser.color(OTChrome.eval(fields[TemplateKey.hintColor], scope)) {
            input.attributedPlaceholder = NSAttributedString(string: hint, attributes: [.foregroundColor: color])
        }
        input.maxLength = fields[TemplateKey.maxLength].flatMap { Int($0) }
        applyKeyboard(input, fields[TemplateKey.inputType] ?? "text")
        switch fields[TemplateKey.textAlign] {
        case "center": input.textAlignment = .center
        case "end": input.textAlignment = .right
        default: input.textAlignment = .left
        }
        input.suppressChange = false
    }

    private static func bindArea(_ area: OTInputArea, _ fields: [String: String], _ scope: JSONObject?, _ scale: CGFloat) {
        area.suppressChange = true
        area.font = OTLayoutEngine.fontFor(fields, scale: scale)
        area.textColor = OTColorParser.color(OTChrome.eval(fields[TemplateKey.textColor], scope)) ?? OTColorParser.color("#1F1A17")
        area.textValue = OTChrome.eval(fields[TemplateKey.textValue], scope) ?? ""
        area.maxLength = fields[TemplateKey.maxLength].flatMap { Int($0) }
        switch fields[TemplateKey.textAlign] {
        case "center": area.textAlignment = .center
        case "end": area.textAlignment = .right
        default: area.textAlignment = .left
        }
        area.suppressChange = false
    }

    private static func applyKeyboard(_ input: UITextField, _ type: String) {
        switch type {
        case "number":
            input.keyboardType = .numberPad
            input.isSecureTextEntry = false
        case "password":
            input.keyboardType = .default
            input.isSecureTextEntry = true
        case "email":
            input.keyboardType = .emailAddress
            input.isSecureTextEntry = false
        case "phone":
            input.keyboardType = .phonePad
            input.isSecureTextEntry = false
        default:
            input.keyboardType = .default
            input.isSecureTextEntry = false
        }
    }

    private static func bindCheck(_ box: OTCheckView, _ fields: [String: String], _ scope: JSONObject?, _ scale: CGFloat) {
        let checked = (OTChrome.eval(fields[TemplateKey.checked], scope) ?? "false") == "true"
        box.setCheckedSilently(checked)
        box.label.text = OTChrome.eval(fields[TemplateKey.textValue], scope) ?? ""
        box.label.font = OTLayoutEngine.fontFor(merged(fields, size: "14"), scale: scale)
        box.label.textColor = OTColorParser.color(OTChrome.eval(fields[TemplateKey.textColor], scope)) ?? OTColorParser.color("#1F1A17")
        let tint = OTColorParser.color(OTChrome.eval(fields[TemplateKey.tint], scope)) ?? OTColorParser.color("#1F6F6A") ?? .systemTeal
        box.box.layer.borderWidth = 1.5
        box.box.layer.borderColor = tint.cgColor
        box.box.backgroundColor = checked ? tint : .clear
        box.mark.strokeColor = UIColor.white.cgColor
    }

    private static func bindRadio(_ radio: OTRadioView, _ fields: [String: String], _ scope: JSONObject?, _ scale: CGFloat) {
        radio.groupName = OTChrome.eval(fields[TemplateKey.group], scope) ?? ""
        let checked = (OTChrome.eval(fields[TemplateKey.checked], scope) ?? "false") == "true"
        radio.setCheckedSilently(checked)
        radio.label.text = OTChrome.eval(fields[TemplateKey.textValue], scope) ?? ""
        radio.label.font = OTLayoutEngine.fontFor(merged(fields, size: "14"), scale: scale)
        radio.label.textColor = OTColorParser.color(OTChrome.eval(fields[TemplateKey.textColor], scope)) ?? OTColorParser.color("#1F1A17")
        let tint = OTColorParser.color(OTChrome.eval(fields[TemplateKey.tint], scope)) ?? OTColorParser.color("#1F6F6A") ?? .systemTeal
        radio.dot.layer.borderColor = tint.cgColor
        radio.dot.backgroundColor = .clear
    }

    private static func bindSwitch(_ toggle: OTSwitchView, _ fields: [String: String], _ scope: JSONObject?, _ scale: CGFloat) {
        let checked = (OTChrome.eval(fields[TemplateKey.checked], scope) ?? "false") == "true"
        toggle.setCheckedSilently(checked)
        toggle.label.text = OTChrome.eval(fields[TemplateKey.textValue], scope) ?? ""
        toggle.label.font = OTLayoutEngine.fontFor(merged(fields, size: "14"), scale: scale)
        toggle.label.textColor = OTColorParser.color(OTChrome.eval(fields[TemplateKey.textColor], scope)) ?? OTColorParser.color("#1F1A17")
        if let tint = OTColorParser.color(OTChrome.eval(fields[TemplateKey.tint], scope)) {
            toggle.track.onTintColor = tint
        }
    }

    private static func merged(_ fields: [String: String], size: String) -> [String: String] {
        var copy = fields
        if copy[TemplateKey.textSize] == nil { copy[TemplateKey.textSize] = size }
        return copy
    }

    private static func padding(_ fields: [String: String], _ scale: CGFloat) -> UIEdgeInsets {
        func edge(_ specific: String) -> CGFloat {
            let raw = fields[specific] ?? fields[TemplateKey.padding]
            return OTMeasure.points(raw, scale: scale) ?? 0
        }
        return UIEdgeInsets(top: edge(TemplateKey.paddingTop), left: edge(TemplateKey.paddingStart), bottom: edge(TemplateKey.paddingBottom), right: edge(TemplateKey.paddingEnd))
    }

    private static func configureList(_ list: OTListView, parsed: ParsedNode, laid: OTLaidOutNode, template: OTTemplateContext) {
        list.template = template
        list.itemTemplate = parsed.item
        list.windowWidth = template.viewport.width
        let gap = OTMeasure.points(parsed.attrs[TemplateKey.itemPadding] ?? "0", scale: template.scale) ?? 0
        list.apply(direction: parsed.attrs[TemplateKey.listDirection] ?? TemplateKey.vertical, gap: gap)
        let expression = parsed.attrs[TemplateKey.data] ?? ""
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = trimmed.hasPrefix("$") ? String(trimmed.dropFirst()) : nil
        list.setItems(OTData.listArray(expression, template.data), key: key?.contains(".") == true ? nil : key)
    }
}

