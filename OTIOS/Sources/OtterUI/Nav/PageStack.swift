import OtterCore
import UIKit

struct ListScroll {
    var position: Int
    var offset: CGFloat
}

/// Port of Android `PageStack`. One container swaps template pages.
/// Process-death restore uses the scene `NSUserActivity` when UIKit hands it back.
/// iOS has no `Bundle` transaction cap. Payloads longer than 200_000 characters are
/// dropped and the stack reopens `start`, matching Android. If the system does not
/// return the activity, this does not invent a restored stack.
public final class PageStack: NSObject, UIGestureRecognizerDelegate {
    public static let maxStateCharacters = 200_000
    public private(set) var depth = 0
    private let host: UIViewController
    private let insetRoot: UIView
    private let container: UIView
    private let routes: PageRouteTable
    private let routePath: String
    private let bizId: String
    private let templateId: String
    private var frames: [Frame] = []
    private var names: [String] = []
    private let stage = UIView()
    private var ownsInsets = false
    private var insetsApplied = false
    private var startAttempted = false
    private var released = false
    private var laidOutSize = CGSize.zero
    private var keyboard: CGFloat = 0
    private var pendingDrop: Frame?
    private var dismissing: Frame?
    private var generation = 0
    private var restored: [SavedPage]?
    private let touchGuard = UIView()
    private weak var edge: UIScreenEdgePanGestureRecognizer?
    private var edgeFrame: Frame?
    private var deferred: [() -> Void] = []
    private var scheduled = false

    public var onInsets: (() -> Void)?

    public static func attach(host: UIViewController, insetRoot: UIView, container: UIView, routePath: String, bizId: String, templateId: String) throws -> PageStack {
        let json = try OTAssets.text(routePath)
        let routes = try PageRouteParser.parse(json)
        let list = PageStack.groups[ObjectIdentifier(host)] ?? []
        let stack = PageStack(host: host, insetRoot: insetRoot, container: container, routes: routes, routePath: routePath, bizId: bizId, templateId: templateId)
        stack.ownsInsets = !list.contains { $0.ownsInsets }
        var next = list
        next.append(stack)
        PageStack.groups[ObjectIdentifier(host)] = next
        if PageStack.active[ObjectIdentifier(host)] == nil { PageStack.active[ObjectIdentifier(host)] = stack }
        stack.install()
        return stack
    }

    public static func find(_ view: UIView) -> PageStack? {
        guard let controller = view.ot_controller else { return nil }
        return PageStack.active[ObjectIdentifier(controller)]
    }

    public func activate() {
        guard !released, let controller = host as UIViewController? else { return }
        PageStack.active[ObjectIdentifier(controller)] = self
        PageStack.groups[ObjectIdentifier(controller)]?.forEach { $0.syncBack() }
    }

    public func releaseStack() {
        guard !released else { return }
        released = true
        endMotion()
        frames.forEach { sever($0) }
        frames.removeAll()
        names.removeAll()
        depth = 0
        if stage.superview === container { stage.removeFromSuperview() }
        if let list = PageStack.groups[ObjectIdentifier(host)] {
            PageStack.groups[ObjectIdentifier(host)] = list.filter { $0 !== self }
            if PageStack.groups[ObjectIdentifier(host)]?.isEmpty == true { PageStack.groups.removeValue(forKey: ObjectIdentifier(host)) }
        }
        if PageStack.active[ObjectIdentifier(host)] === self { PageStack.active.removeValue(forKey: ObjectIdentifier(host)) }
        NotificationCenter.default.removeObserver(self)
    }

    public func layoutContainers() {
        let owner = PageStack.groups[ObjectIdentifier(host)]?.first { $0.ownsInsets } ?? self
        let safe = owner.insetRoot.safeAreaInsets
        let bottom = max(safe.bottom, owner.keyboard)
        let rootInset = owner.insetRoot.bounds.inset(by: UIEdgeInsets(top: safe.top, left: safe.left, bottom: bottom, right: safe.right))
        let local = container.convert(rootInset, from: owner.insetRoot)
        let fitted = container.bounds.intersection(local)
        stage.frame = fitted.isEmpty ? container.bounds : fitted
        insetsApplied = true
        render()
    }

    public func open(_ page: String, _ raw: JSONObject?, _ item: JSONObject?, _ pageData: JSONObject?) {
        guard !released else { return }
        openNow(page, raw, item, pageData)
    }

    public func replace(_ page: String, _ raw: JSONObject?, _ item: JSONObject?, _ pageData: JSONObject?) {
        guard !released else { return }
        replaceNow(page, raw, item, pageData)
    }

    @discardableResult
    public func pop(_ raw: JSONObject? = nil) -> Bool {
        guard !released, names.count > 1 else { return false }
        return popNow(raw)
    }

    @discardableResult
    public func popTo(_ page: String, _ raw: JSONObject?) -> Bool {
        guard !released, names.lastIndex(of: page) != nil else { return false }
        return popToNow(page, raw)
    }

    public func editCurrentData(_ block: (JSONObject) -> Void) {
        guard !released, let frame = frames.last else { return }
        if frame.data == nil {
            frame.data = frame.template?.data ?? JSONObject()
            if frame.template?.data == nil { frame.template?.data = frame.data }
        }
        PageForm.snapshot(frame.template?.rootView, frame.data)
        block(frame.data!)
    }

    public func rebindCurrent() {
        guard !released, let context = frames.last?.template, context.rootView != nil else { return }
        try? OTEngine.shared.rebind(context)
        PageForm.restore(context.rootView, frames.last?.data)
    }

    public func exportState() -> String? {
        guard !released, !frames.isEmpty else { return nil }
        var pages: [[String: Any]] = []
        for frame in frames {
            PageForm.snapshot(frame.template?.rootView, frame.data)
            PageForm.captureScroll(frame.template?.rootView, &frame.scrolls)
            var page: [String: Any] = ["name": frame.name]
            if let data = frame.data, let text = OTData.text(data) {
                page["data"] = text
            }
            if let slot = frame.slotKey {
                page["slotKey"] = slot
                page["slotIndex"] = frame.slotIndex
            }
            if !frame.scrolls.isEmpty {
                var scrolls: [String: [String: Any]] = [:]
                for (key, scroll) in frame.scrolls {
                    scrolls[key] = ["position": scroll.position, "offset": scroll.offset]
                }
                page["scrolls"] = scrolls
            }
            pages.append(page)
        }
        let root: [String: Any] = ["route": routePath, "bizId": bizId, "templateId": templateId, "pages": pages]
        guard let data = try? JSONSerialization.data(withJSONObject: root), let text = String(data: data, encoding: .utf8) else { return nil }
        if text.count > PageStack.maxStateCharacters { return nil }
        return text
    }

    public func restoreState(_ text: String?) {
        guard let text, let data = text.data(using: .utf8), let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if root["route"] as? String != routePath || root["bizId"] as? String != bizId || root["templateId"] as? String != templateId { return }
        guard let pages = root["pages"] as? [[String: Any]], !pages.isEmpty else { return }
        var parsed: [SavedPage] = []
        for page in pages {
            guard let name = page["name"] as? String, routes.pages[name] != nil else { return }
            var scrolls: [String: ListScroll] = [:]
            if let raw = page["scrolls"] as? [String: [String: Any]] {
                for (key, one) in raw {
                    scrolls[key] = ListScroll(position: one["position"] as? Int ?? 0, offset: CGFloat(one["offset"] as? Double ?? 0))
                }
            }
            parsed.append(SavedPage(name: name, data: page["data"] as? String, slotKey: page["slotKey"] as? String, slotIndex: page["slotIndex"] as? Int ?? -1, scrolls: scrolls))
        }
        restored = parsed
    }

    private static var groups: [ObjectIdentifier: [PageStack]] = [:]
    private static var active: [ObjectIdentifier: PageStack] = [:]

    private init(host: UIViewController, insetRoot: UIView, container: UIView, routes: PageRouteTable, routePath: String, bizId: String, templateId: String) {
        self.host = host
        self.insetRoot = insetRoot
        self.container = container
        self.routes = routes
        self.routePath = routePath
        self.bizId = bizId
        self.templateId = templateId
    }

    private func install() {
        stage.clipsToBounds = true
        container.addSubview(stage)
        stage.frame = container.bounds
        stage.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        touchGuard.backgroundColor = .clear
        touchGuard.isUserInteractionEnabled = true
        let edge = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(edgePan(_:)))
        edge.edges = container.effectiveUserInterfaceLayoutDirection == .rightToLeft ? .right : .left
        edge.delegate = self
        container.addGestureRecognizer(edge)
        self.edge = edge
        NotificationCenter.default.addObserver(self, selector: #selector(keyboard(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        if !ownsInsets, PageStack.groups[ObjectIdentifier(host)]?.contains(where: { $0.insetsApplied }) == true {
            insetsApplied = true
        }
        if ownsInsets { insetsApplied = true }
        layoutContainers()
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        names.count > 1 && !released
    }

    @objc private func edgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard names.count > 1, let top = frames.last, let view = top.template?.rootView else { return }
        let width = max(stage.bounds.width, 1)
        let translation = gesture.translation(in: stage).x
        let rtl = stage.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let travel = rtl ? min(translation, 0) : max(translation, 0)
        switch gesture.state {
        case .began:
            edgeFrame = top
            view.layer.removeAllAnimations()
        case .changed:
            view.transform = CGAffineTransform(translationX: travel, y: 0)
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: stage).x
            let passed = abs(travel) > width * 0.35 || abs(velocity) > 800
            if passed && gesture.state == .ended {
                pop(nil)
            } else {
                UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
                    view.transform = .identity
                }
            }
            edgeFrame = nil
        default:
            break
        }
    }

    @objc private func keyboard(_ note: Notification) {
        guard ownsInsets, let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let local = insetRoot.convert(frame, from: nil)
        let overlap = insetRoot.bounds.intersection(local).height
        keyboard = local.minY >= insetRoot.bounds.maxY - 1 ? 0 : overlap
        layoutContainers()
        onInsets?()
    }

    private func render() {
        guard !released, insetsApplied, container.bounds.width > 0, container.bounds.height > 0 else { return }
        if stage.frame.isEmpty { stage.frame = container.bounds }
        if !frames.isEmpty {
            if container.bounds.size == laidOutSize { return }
            laidOutSize = container.bounds.size
            if let frame = frames.last { relayout(frame) }
            return
        }
        if startAttempted { return }
        startAttempted = true
        openStart()
    }

    private func openStart() {
        let saved = restored
        restored = nil
        if saved == nil || saved?.isEmpty == true {
            openNow(routes.start, nil, nil, nil)
            return
        }
        for (index, page) in saved!.enumerated() {
            guard let route = routes.pages[page.name] else {
                abandon(); openNow(routes.start, nil, nil, nil); return
            }
            var data: JSONObject?
            if let text = page.data, !text.isEmpty {
                data = try? OTData.parseObject(text)
                if data == nil { abandon(); openNow(routes.start, nil, nil, nil); return }
            }
            let frame = Frame(name: page.name, templatePath: route.template, data: data, template: nil, slotKey: page.slotKey, slotIndex: page.slotIndex)
            frame.scrolls = page.scrolls
            frames.append(frame)
            names.append(frame.name)
            depth = names.count
            if index == saved!.count - 1 && !materialize(frame, under: false) {
                abandon(); openNow(routes.start, nil, nil, nil); return
            }
        }
        syncBack()
        laidOutSize = container.bounds.size
    }

    private func abandon() {
        frames.forEach { sever($0) }
        frames.removeAll()
        names.removeAll()
        depth = 0
    }

    private func openNow(_ page: String, _ raw: JSONObject?, _ item: JSONObject?, _ pageData: JSONObject?) {
        OTIme.dismiss(insetRoot)
        guard let entry = resolveEntry(page, raw, item, pageData, replace: false), let shown = createShown(page, entry, item) else { return }
        showFrame(shown.0, shown.1)
    }

    private func replaceNow(_ page: String, _ raw: JSONObject?, _ item: JSONObject?, _ pageData: JSONObject?) {
        OTIme.dismiss(insetRoot)
        guard let entry = resolveEntry(page, raw, item, pageData, replace: true), let shown = createShown(page, entry, item) else { return }
        let removed = frames.isEmpty ? nil : frames.removeLast()
        if removed != nil { _ = names.popLast(); depth = names.count }
        if let removed, !frames.isEmpty {
            pendingDrop = removed
            frames.append(shown.0)
            names.append(shown.0.name)
            depth = names.count
            syncBack()
            slideIn(shown.1)
        } else {
            if let removed { swap(shown.0, shown.1, removed) } else { showFrame(shown.0, shown.1) }
        }
        laidOutSize = container.bounds.size
    }

    private func resolveEntry(_ page: String, _ raw: JSONObject?, _ item: JSONObject?, _ pageData: JSONObject?, replace: Bool) -> (PageRoute, Frame?, JSONObject?)? {
        guard !released, let route = routes.pages[page] else {
            OTToast.show("这个页面还打不开", in: container)
            return nil
        }
        let current = frames.last
        if let current, current.data !== pageData, current.template?.data !== pageData, pageData != nil {
            return nil
        }
        if let current {
            PageForm.snapshot(current.template?.rootView, current.data)
            PageForm.captureScroll(current.template?.rootView, &current.scrolls)
        }
        let scope = PageParams.merge(pageData ?? current?.data, item)
        let overlay = raw.map { OTData.evaluate($0, scope) }
        if !replace, let current, current.name == page, PageParams.matches(current.data, overlay) {
            return nil
        }
        return (route, current, overlay)
    }

    private func createShown(_ page: String, _ entry: (PageRoute, Frame?, JSONObject?), _ item: JSONObject?) -> (Frame, UIView)? {
        var created: OTTemplateContext?
        do {
            var base: JSONObject?
            if let dataPath = entry.0.data {
                base = try OTData.parseObject(try OTAssets.text(dataPath))
            }
            let context = OTEngine.shared.buildTemplate(bizId: bizId, templateId: templateId, templatePath: entry.0.template)
            created = context
            if let merged = PageParams.merge(base, entry.2), let text = OTData.text(merged) {
                try OTEngine.shared.setData(context, text)
            }
            let view = try OTEngine.shared.createView(context, viewport: container.bounds.size)
            let slot = PageParams.findItem(entry.1?.data, item)
            let frame = Frame(name: page, templatePath: entry.0.template, data: context.data, template: context, slotKey: slot?.0, slotIndex: slot?.1 ?? -1)
            return (frame, view)
        } catch {
            created?.release()
            OTToast.show("这个页面还打不开", in: container)
            return nil
        }
    }

    private func showFrame(_ frame: Frame, _ view: UIView) {
        endMotion()
        if let covered = frames.last {
            PageForm.snapshot(covered.template?.rootView, covered.data)
            PageForm.captureScroll(covered.template?.rootView, &covered.scrolls)
            pendingDrop = covered
        }
        frames.append(frame)
        names.append(frame.name)
        depth = names.count
        syncBack()
        slideIn(view)
        laidOutSize = container.bounds.size
    }

    private func swap(_ frame: Frame, _ view: UIView, _ removed: Frame) {
        endMotion()
        frames.append(frame)
        names.append(frame.name)
        depth = names.count
        syncBack()
        place(view, under: false)
        sever(removed)
    }

    private func popNow(_ raw: JSONObject?) -> Bool {
        guard !released, names.count > 1 else { return false }
        OTIme.dismiss(insetRoot)
        names.removeLast()
        let frame = frames.removeLast()
        depth = names.count
        guard let revealed = frames.last else { return false }
        endMotion(keep: revealed)
        PageForm.snapshot(frame.template?.rootView, frame.data)
        let result = evaluateBack(raw ?? declaredBack(frame), frame.data)
        if let result, result.size > 0 { applyResult(revealed, frame, result) }
        let keepLive = (result == nil || result?.size == 0) && revealed.template?.rootView != nil
        if !keepLive {
            sever(revealed)
            if !materialize(revealed, under: frame.template?.rootView != nil) {
                OTToast.show("这个页面还打不开", in: container)
            }
        }
        syncBack()
        dismiss(frame)
        laidOutSize = container.bounds.size
        return true
    }

    private func popToNow(_ page: String, _ raw: JSONObject?) -> Bool {
        guard let index = names.lastIndex(of: page) else { return false }
        OTIme.dismiss(insetRoot)
        if index == names.count - 1 {
            mergeIntoTop(raw)
            return true
        }
        let removed = Array(frames[(index + 1)...])
        frames.removeSubrange((index + 1)...)
        names.removeSubrange((index + 1)...)
        depth = names.count
        guard let revealed = frames.last, let visible = removed.first else { return false }
        let covering = removed.last ?? visible
        endMotion(keep: revealed)
        PageForm.snapshot(visible.template?.rootView, visible.data)
        let result = evaluateBack(raw, visible.data)
        if let result, result.size > 0 { applyResult(revealed, covering, result) }
        let keepLive = (result == nil || result?.size == 0) && revealed.template?.rootView != nil
        if !keepLive {
            sever(revealed)
            if !materialize(revealed, under: visible.template?.rootView != nil) {
                OTToast.show("这个页面还打不开", in: container)
            }
        }
        syncBack()
        for extra in removed.dropFirst() { sever(extra) }
        dismiss(visible)
        laidOutSize = container.bounds.size
        return true
    }

    private func mergeIntoTop(_ raw: JSONObject?) {
        guard let top = frames.last else { return }
        endMotion(keep: top)
        PageForm.snapshot(top.template?.rootView, top.data)
        let result = evaluateBack(raw, top.data)
        if let result, result.size > 0 {
            top.data = PageParams.merge(top.data, result)
            sever(top)
            if !materialize(top, under: false) { OTToast.show("这个页面还打不开", in: container) }
        }
    }

    private func applyResult(_ revealed: Frame, _ leaving: Frame, _ result: JSONObject) {
        if let key = leaving.slotKey, let array = revealed.data?.getJSONArray(key), leaving.slotIndex >= 0, leaving.slotIndex < array.size, let item = array.getJSONObject(leaving.slotIndex) {
            PageParams.mergeInto(item, result)
            return
        }
        revealed.data = PageParams.merge(revealed.data, result)
    }

    private func evaluateBack(_ raw: JSONObject?, _ scope: JSONObject?) -> JSONObject? {
        guard let raw else { return nil }
        return OTData.evaluate(raw, scope)
    }

    private func declaredBack(_ frame: Frame) -> JSONObject? {
        let found = frame.template?.events.values.compactMap { event -> JSONObject? in
            guard event.getString("class") == "nav", event.getJSONObject("params")?.getString("fun") == "back" else { return nil }
            return event.getJSONObject("params")?.getJSONObject("params")
        } ?? []
        return found.count == 1 ? found[0] : nil
    }

    private func materialize(_ frame: Frame, under: Bool) -> Bool {
        if let existing = frame.template?.rootView {
            if existing.superview == nil { place(existing, under: under) }
            PageForm.restore(existing, frame.data)
            PageForm.restoreScroll(existing, frame.scrolls)
            relayout(frame)
            return true
        }
        let context = OTEngine.shared.buildTemplate(bizId: bizId, templateId: templateId, templatePath: frame.templatePath)
        do {
            if let data = frame.data, let text = OTData.text(data) {
                try OTEngine.shared.setData(context, text)
            }
            let view = try OTEngine.shared.createView(context, viewport: container.bounds.size)
            frame.template = context
            frame.data = context.data
            PageForm.restore(view, frame.data)
            place(view, under: under)
            PageForm.restoreScroll(view, frame.scrolls)
            relayout(frame)
            return true
        } catch {
            context.release()
            frame.template = nil
            return false
        }
    }

    private func place(_ view: UIView, under: Bool) {
        if view.superview === stage { return }
        view.frame = stage.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if under && stage.subviews.count > 0 {
            stage.insertSubview(view, at: 0)
        } else {
            stage.addSubview(view)
        }
    }

    private func slideIn(_ view: UIView) {
        holdTouches()
        place(view, under: false)
        let travel = travel()
        if travel == 0 {
            severPending()
            releaseTouches()
            return
        }
        view.transform = CGAffineTransform(translationX: travel, y: 0)
        let token = nextGeneration()
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            view.transform = .identity
        } completion: { _ in
            guard token == self.generation, !self.released else { return }
            self.severPending()
            if self.dismissing == nil { self.releaseTouches() }
        }
    }

    private func dismiss(_ frame: Frame) {
        guard let view = frame.template?.rootView else {
            sever(frame)
            releaseTouches()
            return
        }
        let travel = travel()
        if travel == 0 {
            sever(frame)
            releaseTouches()
            return
        }
        holdTouches()
        stage.bringSubviewToFront(view)
        dismissing = frame
        let token = nextGeneration()
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            view.transform = CGAffineTransform(translationX: travel, y: 0)
        } completion: { _ in
            guard token == self.generation, !self.released else { return }
            if self.dismissing === frame {
                self.dismissing = nil
                self.sever(frame)
            }
            if self.dismissing == nil { self.releaseTouches() }
        }
    }

    private func travel() -> CGFloat {
        let width = stage.bounds.width > 0 ? stage.bounds.width : container.bounds.width
        if width <= 0 || container.bounds.height <= 0 { return 0 }
        if UIAccessibility.isReduceMotionEnabled { return 0 }
        return stage.effectiveUserInterfaceLayoutDirection == .rightToLeft ? -width : width
    }

    private func holdTouches() {
        touchGuard.frame = stage.bounds
        touchGuard.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        stage.addSubview(touchGuard)
    }

    private func releaseTouches() { touchGuard.removeFromSuperview() }

    private func endMotion(keep: Frame? = nil) {
        generation += 1
        stage.subviews.forEach { $0.layer.removeAllAnimations(); $0.transform = .identity }
        releaseTouches()
        if let drop = pendingDrop, drop !== keep { sever(drop) }
        pendingDrop = nil
        if let closing = dismissing, closing !== keep { sever(closing) }
        dismissing = nil
    }

    private func severPending() {
        if let frame = pendingDrop { pendingDrop = nil; sever(frame) }
    }

    private func sever(_ frame: Frame) {
        let data = frame.data
        guard let context = frame.template else { return }
        context.rootView?.removeFromSuperview()
        context.release()
        frame.template = nil
        frame.data = data
    }

    private func relayout(_ frame: Frame) {
        guard let context = frame.template else { return }
        OTEngine.shared.relayout(context, viewport: container.bounds.size)
        context.rootView?.frame = stage.bounds
    }

    private func syncBack() {
        host.navigationController?.interactivePopGestureRecognizer?.isEnabled = names.count <= 1
    }

    private func nextGeneration() -> Int {
        generation += 1
        return generation
    }

    private final class Frame {
        var name: String
        var templatePath: String
        var data: JSONObject?
        var template: OTTemplateContext?
        var slotKey: String?
        var slotIndex: Int
        var scrolls: [String: ListScroll] = [:]
        init(name: String, templatePath: String, data: JSONObject?, template: OTTemplateContext?, slotKey: String?, slotIndex: Int) {
            self.name = name
            self.templatePath = templatePath
            self.data = data
            self.template = template
            self.slotKey = slotKey
            self.slotIndex = slotIndex
        }
    }

    private struct SavedPage {
        var name: String
        var data: String?
        var slotKey: String?
        var slotIndex: Int
        var scrolls: [String: ListScroll]
    }
}

enum PageForm {
    static func snapshot(_ root: UIView?, _ data: JSONObject?) {
        guard let root, let data else { return }
        write(root, data)
    }

    static func restore(_ root: UIView?, _ data: JSONObject?) {
        guard let root, let data else { return }
        apply(root, data)
    }

    static func captureScroll(_ root: UIView?, _ into: inout [String: ListScroll]) {
        guard let root else { return }
        var found: [String: ListScroll] = [:]
        readScroll(root, "0", &found)
        into = found
    }

    static func restoreScroll(_ root: UIView?, _ scrolls: [String: ListScroll]) {
        guard let root, !scrolls.isEmpty else { return }
        DispatchQueue.main.async {
            guard root.superview != nil else { return }
            applyScroll(root, "0", scrolls)
        }
    }

    private static func write(_ view: UIView, _ data: JSONObject) {
        if view is OTListView || view is OTItemView { return }
        if let id = OTViewMark.bind(view).idName {
            if let input = view as? OTInputting { data[id] = .string(input.textValue) }
            if let check = view as? OTCheckable { data[id] = .bool(check.checked) }
        }
        let children = (view as? OTColumnView)?.scrolling == true ? (view as! OTColumnView).scrollContent.templateChildren : (view as? OTAbsoluteView)?.templateChildren ?? view.subviews
        for child in children { write(child, data) }
    }

    private static func apply(_ view: UIView, _ data: JSONObject) {
        if view is OTListView || view is OTItemView { return }
        if let id = OTViewMark.bind(view).idName, let value = data.get(id) {
            if let input = view as? OTInputting, let text = value.string {
                input.suppressChange = true
                input.textValue = text
                input.suppressChange = false
            }
            if let check = view as? OTCheckable, case .bool(let flag) = value {
                check.setCheckedSilently(flag)
            }
        }
        let children = (view as? OTAbsoluteView)?.templateChildren ?? view.subviews
        for child in children { apply(child, data) }
    }

    private static func readScroll(_ view: UIView, _ path: String, _ into: inout [String: ListScroll]) {
        if let list = view as? OTListView, let scroll = list.firstScroll {
            into[path] = ListScroll(position: scroll.index, offset: scroll.offset)
            return
        }
        if view is OTItemView { return }
        let children = (view as? OTAbsoluteView)?.templateChildren ?? view.subviews
        for (index, child) in children.enumerated() {
            readScroll(child, "\(path)/\(index)", &into)
        }
    }

    private static func applyScroll(_ view: UIView, _ path: String, _ scrolls: [String: ListScroll]) {
        if let list = view as? OTListView, let scroll = scrolls[path] {
            list.restoreScroll(index: scroll.position, offset: scroll.offset)
            return
        }
        if view is OTItemView { return }
        let children = (view as? OTAbsoluteView)?.templateChildren ?? view.subviews
        for (index, child) in children.enumerated() {
            applyScroll(child, "\(path)/\(index)", scrolls)
        }
    }
}
