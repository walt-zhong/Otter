import OtterCore
import UIKit

final class MarketController: UIViewController {
    private let session = MarketSession()
    private var permissions: OTPermissionCenter?
    private let containers: [String: UIView] = ["home": UIView(), "orders": UIView(), "mine": UIView()]
    private let tabs = ["home", "orders", "mine"]
    private var labels: [UILabel] = []
    private var marks: [UIView] = []
    private var selected = 0
    private let accent = UIColor(red: 139 / 255, green: 87 / 255, blue: 42 / 255, alpha: 1)
    private let muted = UIColor(red: 138 / 255, green: 129 / 255, blue: 120 / 255, alpha: 1)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        permissions = OTPermissionCenter.install(host: self, prompts: nanshiPrompts())
        let bar = UIView()
        bar.backgroundColor = .white
        view.addSubview(bar)
        let names = ["南市", "订单", "我的"]
        for (index, name) in names.enumerated() {
            let label = UILabel()
            label.text = name
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 13)
            labels.append(label)
            let mark = UIView()
            mark.backgroundColor = accent
            marks.append(mark)
            let button = UIButton(type: .system)
            button.tag = index
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            bar.addSubview(button)
            bar.addSubview(label)
            bar.addSubview(mark)
            button.accessibilityIdentifier = tabs[index]
        }
        for (name, container) in containers {
            container.isHidden = name != "home"
            view.addSubview(container)
        }
        view.viewWithTag(900)?.removeFromSuperview()
        bar.tag = 900
        session.shops = readShops()
        session.openTab = { [weak self] page in
            guard let self, let index = self.tabs.firstIndex(of: page) else { return }
            self.showTab(page, index)
        }
        session.activate(host: self)
        do {
            let home = try PageStack.attach(host: self, insetRoot: view, container: containers["home"]!, routePath: "templates/market/routes.json", bizId: "demo", templateId: "market")
            let orders = try PageStack.attach(host: self, insetRoot: view, container: containers["orders"]!, routePath: "templates/market/routes-orders.json", bizId: "demo", templateId: "market")
            let mine = try PageStack.attach(host: self, insetRoot: view, container: containers["mine"]!, routePath: "templates/market/routes-mine.json", bizId: "demo", templateId: "market")
            session.stacks = [home, orders, mine]
            session.stack = home
            home.activate()
        } catch {
            OTToast.show(error.localizedDescription, in: view)
        }
        let edge = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(rootBack))
        edge.edges = .left
        view.addGestureRecognizer(edge)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.safeAreaInsets
        let barHeight: CGFloat = 52
        let bar = view.viewWithTag(900)!
        bar.frame = CGRect(x: 0, y: view.bounds.height - safe.bottom - barHeight, width: view.bounds.width, height: barHeight)
        let width = view.bounds.width / 3
        for index in 0..<3 {
            let button = bar.subviews.compactMap { $0 as? UIButton }.first { $0.tag == index }
            button?.frame = CGRect(x: width * CGFloat(index), y: 0, width: width, height: barHeight)
            labels[index].frame = CGRect(x: width * CGFloat(index), y: 8, width: width, height: 24)
            marks[index].frame = CGRect(x: width * CGFloat(index) + width / 2 - 10, y: 34, width: 20, height: 2)
        }
        let content = CGRect(x: 0, y: 0, width: view.bounds.width, height: bar.frame.minY)
        for container in containers.values {
            container.frame = content
        }
        session.stacks.forEach { $0.layoutContainers() }
        paintTabs()
    }

    @objc private func tabTapped(_ sender: UIButton) {
        showTab(tabs[sender.tag], sender.tag)
    }

    @objc private func rootBack() {
        if let stack = session.stack, stack.depth > 1 {
            stack.pop(nil)
            return
        }
        if selected != 0 {
            showTab("home", 0)
            return
        }
        navigationController?.popViewController(animated: true)
    }

    private func showTab(_ page: String, _ index: Int) {
        guard tabs.indices.contains(index), session.stacks.indices.contains(index) else { return }
        let target = session.stacks[index]
        session.stack = target
        target.activate()
        for (name, container) in containers {
            if name != page { container.endEditing(true) }
            container.isHidden = name != page
        }
        selected = index
        paintTabs()
        if page == "mine" { permissions?.publishAll(containers["mine"] ?? view) }
    }

    private func paintTabs() {
        for index in labels.indices {
            let on = index == selected
            labels[index].textColor = on ? accent : muted
            labels[index].font = .systemFont(ofSize: 13, weight: on ? .bold : .regular)
            marks[index].isHidden = !on
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            permissions?.releaseCenter()
            session.release()
        }
    }

    private func readShops() -> JSONArray {
        guard let text = try? OTAssets.text("templates/market/mock-data/home.json"),
              let root = try? OTData.parseObject(text),
              let shops = root.getJSONArray("shops") else { return JSONArray() }
        return shops
    }

    private func nanshiPrompts() -> [String: PermissionPrompt] {
        [
            PermissionCapability.CAMERA: PermissionPrompt(title: "拍菜单", message: "南市想用相机，拍下黑板上的字。这次只确认允不允许，还不会打开相机。"),
            PermissionCapability.MICROPHONE: PermissionPrompt(title: "留一句", message: "南市想用麦克风，留一句给店员。这次只确认允不允许，还不会录音。"),
            PermissionCapability.LOCATION_WHEN_IN_USE: PermissionPrompt(title: "走到巷口", message: "只在你查看南市时使用位置，用来判断你在不在这条巷。不会在后台定位。你可以只给大致位置。"),
            PermissionCapability.PHOTOS: PermissionPrompt(title: "换头像", message: "从相册选一张做头像。只会拿到你点中的那张，不会读取整个相册。"),
            PermissionCapability.NOTIFICATIONS: PermissionPrompt(title: "取餐通知", message: "摊位做好了就通知你。接下来会弹出系统对话框，你可以拒绝。")
        ]
    }
}

final class MarketSession {
    var stack: PageStack?
    var stacks: [PageStack] = []
    var shops = JSONArray()
    var openTab: ((String) -> Void)?
    private weak var host: UIViewController?

    func activate(host: UIViewController) {
        self.host = host
        let center = ExpansionCenter.shared
        center.registerHostAction("pay") { [weak self] view, params in self?.pay(view, params) }
        center.registerHostAction("setQty") { [weak self] _, params in self?.setQty(params) }
        center.registerHostAction("removeLine") { [weak self] _, params in self?.removeLine(params) }
        center.registerHostAction("refreshStatus") { [weak self] view, _ in self?.refreshStatus(view) }
        center.registerHostAction("call") { [weak self] view, params in self?.callShop(view, params) }
        center.registerHostAction("filter") { [weak self] _, params in self?.filter(params) }
        center.registerHostAction("openTab") { [weak self] _, params in
            guard let page = params?.getString("page") else { return }
            self?.openTab?(page)
        }
    }

    func release() {
        stacks.forEach { $0.releaseStack() }
        stacks = []
        stack = nil
        openTab = nil
    }

    private func pay(_ view: UIView, _ params: JSONObject?) {
        guard let host, let paying = stack else { return }
        let amount = string(params, "amount")
        let alert = UIAlertController(title: "确认支付", message: amount, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确认", style: .default) { _ in
            let payload = JSONObject()
            payload["orderNo"] = .string(self.nextOrderNo())
            payload["amount"] = .string(amount)
            paying.replace("result", payload, nil, nil)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        host.present(alert, animated: true)
    }

    private func setQty(_ params: JSONObject?) {
        guard let current = stack else { return }
        let lineId = string(params, "lineId")
        guard let qty = parseQty(string(params, "qty")), !lineId.isEmpty else { return }
        current.editCurrentData { data in
            guard let lines = data.getJSONArray("lines") else { return }
            for index in 0..<lines.size {
                guard let line = lines.getJSONObject(index), line.getString("lineId") == lineId else { continue }
                self.applyQty(line, qty)
                break
            }
            self.writeTotal(data, lines)
        }
        current.rebindCurrent()
    }

    private func removeLine(_ params: JSONObject?) {
        guard let current = stack else { return }
        let lineId = string(params, "lineId")
        guard !lineId.isEmpty else { return }
        current.editCurrentData { data in
            guard let lines = data.getJSONArray("lines") else { return }
            let kept = JSONArray()
            for index in 0..<lines.size {
                guard let line = lines.getJSONObject(index), line.getString("lineId") != lineId else { continue }
                kept.add(.object(line))
            }
            data["lines"] = .array(kept)
            self.writeTotal(data, kept)
        }
        current.rebindCurrent()
    }

    private func refreshStatus(_ view: UIView) {
        guard let current = stack else { return }
        current.editCurrentData { data in
            guard let orders = data.getJSONArray("orders"), orders.size > 0, let first = orders.getJSONObject(0) else { return }
            if first.getString("status") == "制作中" {
                first["status"] = .string("可取餐")
                first["statusNote"] = .string("可以到柜台取了，手冲还是热的。")
            }
        }
        current.rebindCurrent()
        OTToast.show("订单状态已更新", in: view)
    }

    private func callShop(_ view: UIView, _ params: JSONObject?) {
        OTToast.show("正在联系店铺 \(string(params, "phone"))", in: view)
    }

    private func filter(_ params: JSONObject?) {
        guard let current = stack else { return }
        let query = string(params, "query").trimmingCharacters(in: .whitespacesAndNewlines)
        current.editCurrentData { data in
            let filtered = JSONArray()
            for index in 0..<self.shops.size {
                guard let shop = self.shops.getJSONObject(index) else { continue }
                let name = shop.getString("name") ?? ""
                if query.isEmpty || name.contains(query) {
                    if let copy = OTData.value(from: OTData.foundationValue(.object(shop))).jsonObject {
                        filtered.add(.object(copy))
                    }
                }
            }
            data["shops"] = .array(filtered)
            data["query"] = .string(query)
            data["noResult"] = .bool(!query.isEmpty && filtered.size == 0)
        }
        current.rebindCurrent()
    }

    private func applyQty(_ line: JSONObject, _ qty: Int) {
        let safe = max(qty, 1)
        let amount = intValue(line, "price") * safe
        line["qty"] = .number(.int(safe))
        line["qtyText"] = .string(String(safe))
        line["qtyMinus"] = .string(String(safe > 1 ? safe - 1 : 1))
        line["qtyPlus"] = .string(String(safe + 1))
        line["amount"] = .string(String(amount))
    }

    private func writeTotal(_ data: JSONObject, _ lines: JSONArray) {
        var total = 0
        for index in 0..<lines.size {
            guard let line = lines.getJSONObject(index) else { continue }
            total += intValue(line, "price") * intValue(line, "qty")
        }
        data["total"] = .string(String(total))
        data["totalLabel"] = .string("\(total) 元")
        data["empty"] = .bool(lines.size == 0)
    }

    private func intValue(_ object: JSONObject, _ key: String) -> Int {
        switch object.get(key) {
        case .number(let number): return number.intValue
        case .string(let text): return Int(text) ?? Int(Double(text) ?? 0)
        default: return 0
        }
    }

    private func parseQty(_ raw: String) -> Int? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }
        if let value = Int(text) { return value }
        return Double(text).map { Int($0) }
    }

    private func nextOrderNo() -> String {
        String(format: "NS%06d", Int(Date().timeIntervalSince1970 * 1000) % 1_000_000)
    }

    private func string(_ object: JSONObject?, _ key: String) -> String {
        guard let object, object.containsKey(key) else { return "" }
        switch object.get(key) {
        case .string(let text): return text
        case .number(let number): return number.description
        case .bool(let flag): return flag ? "true" : "false"
        default: return ""
        }
    }
}
