import OtterCore
import OtterExpression
import OtterLayout
import UIKit

enum OTEvents {
    static func attachClick(_ view: UIView, names: [String]) {
        let bind = OTViewMark.bind(view)
        bind.clickNames = names
        bind.hasClick = !names.isEmpty
        guard !names.isEmpty else { return }
        view.isUserInteractionEnabled = true
        if view.gestureRecognizers?.contains(where: { $0.name == "otter.click" }) == true { return }
        let tap = UITapGestureRecognizer(target: ClickTarget.shared, action: #selector(ClickTarget.tapped(_:)))
        tap.name = "otter.click"
        tap.delegate = OTClickGate.shared
        view.addGestureRecognizer(tap)
    }

    static func fireChange(_ view: UIView) {
        let bind = OTViewMark.bind(view)
        guard let template = bind.template else { return }
        for name in bind.changeNames {
            dispatch(view, template.events[name], bind.itemData, template)
        }
    }

    static func dispatch(_ view: UIView, _ event: JSONObject?, _ itemData: JSONObject?, _ template: OTTemplateContext) {
        guard let event else { return }
        let params = event.getJSONObject("params") ?? JSONObject()
        switch event.getString("class") {
        case "util": util(view, params, itemData, template)
        case "view": viewEvent(view, params, itemData, template)
        case "nav": nav(view, params, itemData, template)
        case "list": list(view, params, itemData, template)
        default: break
        }
    }

    private static func util(_ view: UIView, _ params: JSONObject, _ item: JSONObject?, _ template: OTTemplateContext) {
        guard params.getString("fun") == "showToast" else { return }
        let text = text(params.getString("info") ?? "", OTData.scope(template.data, item))
        OTToast.show(text, in: view)
    }

    private static func viewEvent(_ view: UIView, _ params: JSONObject, _ item: JSONObject?, _ template: OTTemplateContext) {
        guard params.getString("fun") == "changeAttributes" else { return }
        let merged = OTData.scope(template.data, item)
        switch params.getString("key") {
        case "setText":
            guard let target = resolve(view, template, params.getString("id")) else { return }
            let raw = params.get("value")
            let value = raw?.string ?? text(OTData.display(OTData.foundationValue(raw)), merged)
            if let label = target as? OTTextView { label.text = value }
            if let input = target as? OTInputting {
                input.suppressChange = true
                input.textValue = value
                input.suppressChange = false
            }
        case "setTextStyle":
            guard let target = resolve(view, template, params.getString("id")) else { return }
            applyStyle(target, params.getJSONObject("value"), merged, template.scale)
        case "setChecked":
            let on = OTData.boolText(text(params.getString("value") ?? "false", merged))
            let names = (params.getString("id") ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            for name in names {
                guard let box = resolve(view, template, name) as? OTCheckable else { continue }
                if let radio = box as? OTRadioView, on {
                    radio.setCheckedSilently(true)
                    radio.claimGroup()
                    radio.writeSelf()
                } else {
                    box.setCheckedSilently(on)
                    if let check = box as? OTCheckView { check.writeBack() }
                    if let radio = box as? OTRadioView { radio.writeSelf() }
                    if let toggle = box as? OTSwitchView { toggle.writeBack() }
                }
            }
        default:
            break
        }
    }

    private static func applyStyle(_ view: UIView, _ value: JSONObject?, _ data: JSONObject, _ scale: CGFloat) {
        guard let attributes = value?.getJSONArray("attributes") else { return }
        for index in 0..<attributes.size {
            guard let style = attributes.getJSONObject(index) else { continue }
            if let raw = style.getString(TemplateKey.ATTR_TEXT_SIZE) {
                let font = OTLayoutEngine.fontFor([TemplateKey.ATTR_TEXT_SIZE: raw, TemplateKey.ATTR_FONT_WEIGHT: style.getString(TemplateKey.ATTR_FONT_WEIGHT) ?? ""], scale: scale)
                if let label = view as? UILabel { label.font = font }
                if let field = view as? UITextField { field.font = font }
                if let area = view as? UITextView { area.font = font }
            }
            if let raw = style.getString(TemplateKey.ATTR_TEXT_COLOR), let color = OTColorParser.color(text(raw, data)) {
                if let label = view as? UILabel { label.textColor = color }
                if let field = view as? UITextField { field.textColor = color }
                if let area = view as? UITextView { area.textColor = color }
            }
            if let raw = style.getString(TemplateKey.ATTR_TEXT) {
                let shown = text(raw, data)
                if let label = view as? OTTextView { label.text = shown }
                if let input = view as? OTInputting { input.textValue = shown }
            }
        }
    }

    private static func nav(_ view: UIView, _ params: JSONObject, _ item: JSONObject?, _ template: OTTemplateContext) {
        let merged = OTData.scope(template.data, item)
        switch params.getString("fun") {
        case "back":
            if let stack = PageStack.find(view), stack.pop(params.getJSONObject("params")) { return }
            if let controller = view.ot_controller {
                if let nav = controller.navigationController, nav.viewControllers.count > 1 {
                    nav.popViewController(animated: true)
                } else if controller.presentingViewController != nil {
                    controller.dismiss(animated: true)
                }
            }
        case "open":
            open(view, params, item, template, merged, replace: false)
        case "replace":
            open(view, params, item, template, merged, replace: true)
        case "popTo":
            let page = text(params.getString("page") ?? "", merged)
            if let stack = PageStack.find(view), !page.isEmpty, page != "null", stack.popTo(page, params.getJSONObject("params")) {
                return
            }
            OTToast.show("这个页面还打不开", in: view)
        case "host":
            host(view, params, merged)
        default:
            break
        }
    }

    private static func open(_ view: UIView, _ params: JSONObject, _ item: JSONObject?, _ template: OTTemplateContext, _ merged: JSONObject, replace: Bool) {
        let page = text(params.getString("page") ?? "", merged)
        if let stack = PageStack.find(view) {
            if page.isEmpty || page == "null" {
                OTToast.show("这个页面还打不开", in: view)
                return
            }
            let raw = params.getJSONObject("params")
            if replace {
                stack.replace(page, raw, item, template.data)
            } else {
                stack.open(page, raw, item, template.data)
            }
            return
        }
        guard let opener = ExpansionCenter.shared.pageOpener, !page.isEmpty, page != "null" else {
            OTToast.show("这个页面还打不开", in: view)
            return
        }
        opener(view.ot_controller ?? UIViewController(), page)
    }

    private static func host(_ view: UIView, _ params: JSONObject, _ merged: JSONObject) {
        let name = text(params.getString("name") ?? "", merged)
        if name.isEmpty || name == "null" {
            OTToast.show("这个操作还不能用", in: view)
            return
        }
        let evaluated = params.getJSONObject("params").map { OTData.evaluate($0, merged) }
        if !ExpansionCenter.shared.dispatchHost(view, name, evaluated) {
            OTToast.show("这个操作还不能用", in: view)
        }
    }

    private static func list(_ view: UIView, _ params: JSONObject, _ item: JSONObject?, _ template: OTTemplateContext) {
        switch params.getString("fun") {
        case "append": append(view, params, template)
        case "update": update(view, params, item, template)
        case "remove": remove(view, params, item, template)
        default: break
        }
    }

    private static func append(_ view: UIView, _ params: JSONObject, _ template: OTTemplateContext) {
        guard let input = resolve(view, template, params.getString("from")) as? OTInputting else { return }
        let typed = input.textValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if typed.isEmpty {
            let empty = params.getString("empty") ?? ""
            if !empty.isEmpty { OTToast.show(empty, in: view) }
            return
        }
        guard let listView = resolve(view, template, params.getString("id")) as? OTListView else { return }
        let item = JSONObject()
        if let fields = params.getJSONObject("item") {
            for key in fields.keys { item[key] = .string(fields.getString(key) ?? "") }
        }
        if let field = params.getString("field") { item[field] = .string(typed) }
        if let key = params.getString("data"), let stored = template.data?.getJSONArray(key), stored !== listView.items {
            stored.add(.object(item))
        }
        listView.items.add(.object(item))
        let last = max(listView.items.size - 1, 0)
        listView.reloadData()
        if listView.items.size > 0 {
            listView.scrollToItem(at: IndexPath(item: last, section: 0), at: listView.horizontal ? .centeredHorizontally : .centeredVertically, animated: true)
        }
        input.suppressChange = true
        input.textValue = ""
        input.suppressChange = false
        if let id = OTViewMark.bind(input).idName { template.data?[id] = .string("") }
        OTIme.dismiss(input)
    }

    private static func update(_ view: UIView, _ params: JSONObject, _ item: JSONObject?, _ template: OTTemplateContext) {
        guard let index = resolveIndex(params, item, template.data) else { return }
        guard let fields = params.getJSONObject("item") else { return }
        guard let listView = resolve(view, template, params.getString("id")) as? OTListView else { return }
        if index < 0 || index >= listView.items.size { return }
        guard let target = listView.items.getJSONObject(index) else { return }
        let merged = OTData.scope(template.data, item)
        for key in fields.keys {
            target[key] = .string(text(fields.getString(key) ?? "", merged))
        }
        listView.reloadItems(at: [IndexPath(item: index, section: 0)])
    }

    private static func remove(_ view: UIView, _ params: JSONObject, _ item: JSONObject?, _ template: OTTemplateContext) {
        guard let index = resolveIndex(params, item, template.data) else { return }
        guard let listView = resolve(view, template, params.getString("id")) as? OTListView else { return }
        if index < 0 || index >= listView.items.size { return }
        let kept = JSONArray()
        for cursor in 0..<listView.items.size where cursor != index {
            if let value = listView.items.get(cursor) { kept.add(value) }
        }
        if let key = listView.dataKey {
            template.data?[key] = .array(kept)
        }
        listView.items = kept
        listView.reloadData()
    }

    private static func resolveIndex(_ params: JSONObject, _ item: JSONObject?, _ page: JSONObject?) -> Int? {
        guard let raw = params.getString("index"), !raw.isEmpty else { return nil }
        return Int(text(raw, OTData.scope(page, item)))
    }

    private static func text(_ expression: String, _ data: JSONObject) -> String {
        OTData.display(ExpressionEngine.shared.result(expression: expression, data: OTData.foundation(data)))
    }

    static func resolve(_ view: UIView, _ template: OTTemplateContext, _ id: String?) -> UIView? {
        guard let id, !id.isEmpty else { return nil }
        if OTViewMark.bind(view).idName == id { return view }
        return find(template.rootView, id)
    }

    private static func find(_ view: UIView?, _ id: String) -> UIView? {
        guard let view else { return nil }
        if OTViewMark.bind(view).idName == id { return view }
        if let column = view as? OTColumnView {
            for child in column.templateChildren {
                if let found = find(child, id) { return found }
            }
        }
        for child in view.subviews {
            if let found = find(child, id) { return found }
        }
        return nil
    }
}

private final class ClickTarget: NSObject {
    static let shared = ClickTarget()
    @objc func tapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        let bind = OTViewMark.bind(view)
        guard let template = bind.template else { return }
        for name in bind.clickNames {
            OTEvents.dispatch(view, template.events[name], bind.itemData, template)
        }
    }
}

extension UIView {
    var ot_controller: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }
}
