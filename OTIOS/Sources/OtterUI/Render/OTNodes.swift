import OtterCore
import OtterLayout
import UIKit

final class OTBind {
    weak var template: OTTemplateContext?
    var itemData: JSONObject?
    var clickNames: [String] = []
    var changeNames: [String] = []
    var hasClick = false
    var fields: [String: String] = [:]
    var scale: CGFloat = 1
    var idName: String?
    var radii: [CGFloat] = []
    var glassInteractive = false
    var otterFrame: CGRect = .zero
    var parsed: ParsedNode?
}

enum OTViewMark {
    private static var key: UInt8 = 0
    static func bind(_ view: UIView) -> OTBind {
        if let existing = objc_getAssociatedObject(view, &key) as? OTBind { return existing }
        let created = OTBind()
        objc_setAssociatedObject(view, &key, created, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return created
    }
}

final class OTClickGate: NSObject, UIGestureRecognizerDelegate {
    static let shared = OTClickGate()
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let host = gestureRecognizer.view else { return true }
        var view = touch.view
        while let current = view, current !== host {
            if current is UIControl { return false }
            if OTViewMark.bind(current).hasClick { return false }
            view = current.superview
        }
        return true
    }
}

class OTAbsoluteView: UIView {
    var templateChildren: [UIView] = []
    func placeChildren() {
        for child in templateChildren where !child.isHidden {
            child.frame = OTViewMark.bind(child).otterFrame
        }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        placeChildren()
        if let gradient = layer.sublayers?.first(where: { $0.name == "otter.gradient" }) {
            gradient.frame = bounds
        }
        let radii = OTViewMark.bind(self).radii
        if radii.count == 4, radii.contains(where: { $0 > 0 }), !radii.allSatisfy({ abs($0 - radii[0]) < 0.5 }) {
            let mask = CAShapeLayer()
            mask.path = OTChrome.cornerPath(bounds, radii).cgPath
            layer.mask = mask
        }
        OTGlassLayer.layout(self)
    }
}

final class OTColumnView: OTAbsoluteView {
    private let scroller = UIScrollView()
    let scrollContent = OTAbsoluteView()
    private(set) var scrolling = false
    private let backdrop = UIImageView()
    private var panOffset: CGFloat = 0
    private var panDisplay: CADisplayLink?
    private var panVelocity: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backdrop.contentMode = .scaleAspectFill
        backdrop.clipsToBounds = true
        backdrop.isUserInteractionEnabled = false
        clipsToBounds = true
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panBackdrop(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func ensureScroll() {
        guard !scrolling else { return }
        scrolling = true
        scroller.frame = bounds
        scroller.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scroller.alwaysBounceVertical = true
        scroller.clipsToBounds = true
        scroller.backgroundColor = .clear
        scrollContent.backgroundColor = .clear
        addSubview(scroller)
        scroller.addSubview(scrollContent)
    }

    override func placeChildren() {
        let host: UIView = scrolling ? scrollContent : self
        var bottom: CGFloat = 0
        var right: CGFloat = 0
        for child in templateChildren where !child.isHidden {
            if child.superview !== host { host.addSubview(child) }
            child.frame = OTViewMark.bind(child).otterFrame
            bottom = max(bottom, child.frame.maxY)
            right = max(right, child.frame.maxX)
        }
        if scrolling {
            scroller.frame = bounds
            let size = CGSize(width: max(bounds.width, right), height: max(bottom, bounds.height))
            scrollContent.frame = CGRect(origin: .zero, size: size)
            scroller.contentSize = size
        }
        layoutBackdrop()
    }

    func showBackdrop(named name: String) {
        guard let image = OTAssets.image(named: name) else { return }
        backdrop.image = image
        if backdrop.superview == nil { insertSubview(backdrop, at: 0) }
        panOffset = 0
        layoutBackdrop()
    }

    func clearBackdrop() {
        backdrop.image = nil
        backdrop.removeFromSuperview()
    }

    private func layoutBackdrop() {
        guard let image = backdrop.image, bounds.width > 0 else { return }
        let fitted = bounds.width * image.size.height / max(image.size.width, 1)
        if fitted > bounds.height + 1 {
            let maxOffset = fitted - bounds.height
            panOffset = min(max(panOffset, 0), maxOffset)
            backdrop.frame = CGRect(x: 0, y: -panOffset, width: bounds.width, height: fitted)
            backdrop.contentMode = .scaleToFill
        } else {
            backdrop.frame = bounds
            backdrop.contentMode = .scaleAspectFill
        }
    }

    private func maxPan() -> CGFloat {
        guard let image = backdrop.image, bounds.width > 0 else { return 0 }
        let fitted = bounds.width * image.size.height / max(image.size.width, 1)
        return max(fitted - bounds.height, 0)
    }

    @objc private func panBackdrop(_ gesture: UIPanGestureRecognizer) {
        guard maxPan() > 0 else { return }
        let translation = gesture.translation(in: self)
        if gesture.state == .changed {
            panOffset = min(max(panOffset - translation.y, 0), maxPan())
            gesture.setTranslation(.zero, in: self)
            layoutBackdrop()
        } else if gesture.state == .ended {
            panVelocity = -gesture.velocity(in: self).y
            startFling()
        }
    }

    private func startFling() {
        panDisplay?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(stepFling))
        panDisplay = link
        link.add(to: .main, forMode: .common)
    }

    @objc private func stepFling() {
        panOffset = min(max(panOffset + panVelocity * (1 / 60), 0), maxPan())
        panVelocity *= 0.95
        layoutBackdrop()
        if abs(panVelocity) < 8 || panOffset == 0 || panOffset == maxPan() {
            panDisplay?.invalidate()
            panDisplay = nil
        }
    }
}

extension OTColumnView: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        if maxPan() <= 0 { return false }
        let velocity = pan.velocity(in: self)
        return abs(velocity.y) > abs(velocity.x)
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        false
    }
}

final class OTRowView: OTAbsoluteView {}

final class OTTextView: UILabel {
    var textInset: UIEdgeInsets = .zero
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInset))
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        if let gradient = layer.sublayers?.first(where: { $0.name == "otter.gradient" }) {
            gradient.frame = bounds
        }
    }
}

final class OTImageView: UIImageView {
    var task: URLSessionDataTask?
    var fit = "cover"
    var placeholder: UIColor?
    func load(_ src: String) {
        task?.cancel()
        task = nil
        contentMode = fit == "contain" ? .scaleAspectFit : (fit == "fill" ? .scaleToFill : .scaleAspectFill)
        clipsToBounds = true
        backgroundColor = placeholder
        let trimmed = src.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            image = nil
            return
        }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            guard let url = URL(string: trimmed) else { image = nil; return }
            let current = self
            task = URLSession.shared.dataTask(with: url) { data, _, _ in
                let image = data.flatMap { UIImage(data: $0) }
                DispatchQueue.main.async {
                    if current.task != nil { current.image = image }
                }
            }
            task?.resume()
            return
        }
        if trimmed.hasPrefix("res:") {
            image = OTAssets.image(named: String(trimmed.dropFirst(4)))
            return
        }
        if trimmed.hasPrefix("content:") {
            let rest = String(trimmed.dropFirst("content:".count))
            if rest.hasPrefix("file:"), let url = URL(string: rest) {
                image = UIImage(contentsOfFile: url.path)
            } else {
                image = UIImage(contentsOfFile: rest)
            }
            return
        }
        image = nil
    }
    func releaseImage() {
        task?.cancel()
        task = nil
        image = nil
    }
}

final class OTSpacerView: UIView {}

protocol OTInputting: UIView {
    var textValue: String { get set }
    var suppressChange: Bool { get set }
}

final class OTInputView: UITextField, OTInputting, UITextFieldDelegate {
    var suppressChange = false
    var maxLength: Int?
    var textValue: String {
        get { text ?? "" }
        set {
            if text == newValue { return }
            suppressChange = true
            text = newValue
            suppressChange = false
        }
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        borderStyle = .none
        addTarget(self, action: #selector(changed), for: .editingChanged)
        delegate = self
        returnKeyType = .done
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func changed() {
        if suppressChange { return }
        let bind = OTViewMark.bind(self)
        if let id = bind.idName, let data = bind.itemData ?? bind.template?.data { data[id] = .string(textValue) }
        OTEvents.fireChange(self)
    }
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let maxLength, let current = textField.text, let textRange = Range(range, in: current) else { return true }
        let next = current.replacingCharacters(in: textRange, with: string)
        return next.count <= maxLength
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        OTIme.dismiss(self)
        return true
    }
}

final class OTInputArea: UITextView, OTInputting, UITextViewDelegate {
    var suppressChange = false
    var maxLength: Int?
    var textValue: String {
        get { text ?? "" }
        set {
            if text == newValue { return }
            suppressChange = true
            text = newValue
            suppressChange = false
        }
    }
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        delegate = self
        backgroundColor = .clear
        textContainerInset = .zero
        self.textContainer.lineFragmentPadding = 0
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func textViewDidChange(_ textView: UITextView) {
        if suppressChange { return }
        let bind = OTViewMark.bind(self)
        if let id = bind.idName, let data = bind.itemData ?? bind.template?.data { data[id] = .string(textValue) }
        OTEvents.fireChange(self)
    }
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let maxLength, let current = textView.text, let textRange = Range(range, in: current) else { return true }
        return current.replacingCharacters(in: textRange, with: text).count <= maxLength
    }
}

protocol OTCheckable: UIControl {
    var checked: Bool { get }
    func setCheckedSilently(_ value: Bool)
}

final class OTCheckView: UIControl, OTCheckable {
    let box = UIView()
    let mark = CAShapeLayer()
    let label = UILabel()
    private(set) var checked = false
    override init(frame: CGRect) {
        super.init(frame: frame)
        box.isUserInteractionEnabled = false
        label.isUserInteractionEnabled = false
        addSubview(box)
        addSubview(label)
        box.layer.addSublayer(mark)
        mark.fillColor = nil
        mark.lineWidth = 2
        mark.lineCap = .round
        mark.lineJoin = .round
        addTarget(self, action: #selector(toggle), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func setCheckedSilently(_ value: Bool) {
        checked = value
        setNeedsLayout()
    }
    @objc private func toggle() {
        setCheckedSilently(!checked)
        writeBack()
        OTEvents.fireChange(self)
    }
    func writeBack() {
        let bind = OTViewMark.bind(self)
        if let id = bind.idName, let data = bind.itemData ?? bind.template?.data { data[id] = .bool(checked) }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let side: CGFloat = 18
        box.frame = CGRect(x: 0, y: (bounds.height - side) / 2, width: side, height: side)
        box.layer.cornerRadius = 4
        label.frame = CGRect(x: side + 8, y: 0, width: max(bounds.width - side - 8, 0), height: bounds.height)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 4, y: 9))
        path.addLine(to: CGPoint(x: 8, y: 13))
        path.addLine(to: CGPoint(x: 14, y: 5))
        mark.path = path.cgPath
        mark.frame = box.bounds
        mark.isHidden = !checked
    }
}

final class OTRadioView: UIControl, OTCheckable {
    let dot = UIView()
    let label = UILabel()
    var groupName = ""
    private(set) var checked = false
    override init(frame: CGRect) {
        super.init(frame: frame)
        dot.isUserInteractionEnabled = false
        label.isUserInteractionEnabled = false
        addSubview(dot)
        addSubview(label)
        addTarget(self, action: #selector(toggle), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func setCheckedSilently(_ value: Bool) {
        checked = value
        setNeedsLayout()
    }
    @objc private func toggle() {
        setCheckedSilently(true)
        claimGroup()
        writeAll()
        OTEvents.fireChange(self)
    }
    func claimGroup() {
        guard !groupName.isEmpty else { return }
        clear(scope())
    }
    private func clear(_ view: UIView) {
        if let radio = view as? OTRadioView, radio !== self, radio.groupName == groupName, radio.checked {
            radio.setCheckedSilently(false)
        }
        for child in view.subviews { clear(child) }
    }
    private func writeAll() {
        func walk(_ view: UIView) {
            if let radio = view as? OTRadioView, radio.groupName == groupName {
                radio.writeSelf()
            }
            if view is OTListView || view is OTItemView { return }
            for child in view.subviews { walk(child) }
        }
        walk(scope())
    }
    func writeSelf() {
        let bind = OTViewMark.bind(self)
        if let id = bind.idName, let data = bind.itemData ?? bind.template?.data { data[id] = .bool(checked) }
    }
    private func scope() -> UIView {
        var current: UIView = self
        while let parent = current.superview {
            if parent is OTItemView { return parent }
            current = parent
        }
        return current
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let side: CGFloat = 18
        dot.frame = CGRect(x: 0, y: (bounds.height - side) / 2, width: side, height: side)
        dot.layer.cornerRadius = side / 2
        dot.layer.borderWidth = checked ? 5 : 1.5
        label.frame = CGRect(x: side + 8, y: 0, width: max(bounds.width - side - 8, 0), height: bounds.height)
    }
}

final class OTItemView: UIView {}

final class OTSwitchView: UIControl, OTCheckable {
    let track = UISwitch()
    let label = UILabel()
    var checked: Bool { track.isOn }
    override init(frame: CGRect) {
        super.init(frame: frame)
        track.addTarget(self, action: #selector(toggled), for: .valueChanged)
        label.isUserInteractionEnabled = false
        addSubview(track)
        addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func setCheckedSilently(_ value: Bool) {
        track.setOn(value, animated: false)
    }
    @objc private func toggled() {
        let bind = OTViewMark.bind(self)
        writeBack()
        OTEvents.fireChange(self)
    }
    func writeBack() {
        let bind = OTViewMark.bind(self)
        if let id = bind.idName, let data = bind.itemData ?? bind.template?.data { data[id] = .bool(track.isOn) }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = track.intrinsicContentSize.width
        let height = track.intrinsicContentSize.height
        track.frame = CGRect(x: 0, y: (bounds.height - height) / 2, width: width, height: height)
        label.frame = CGRect(x: width + 8, y: 0, width: max(bounds.width - width - 8, 0), height: bounds.height)
    }
}

final class OTProgressView: UIView {
    var from: CGFloat = 0
    var to: CGFloat = 1
    var trackColor = UIColor.gray
    var barColor = UIColor.red
    var animate = false
    var seekable = false
    var onSeek: ((CGFloat, Bool) -> Void)?
    private var shown: CGFloat = 0
    private let trackLayer = CALayer()
    private let barLayer = CALayer()
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(trackLayer)
        layer.addSublayer(barLayer)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func bind(from: CGFloat, to: CGFloat, animate: Bool) {
        self.from = min(max(from, 0), 1)
        self.to = min(max(to, 0), 1)
        self.animate = animate
        setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let pad: CGFloat = 1
        let full = max(bounds.height - pad * 2, 0)
        let slim = 6 * traitCollection.displayScale / max(traitCollection.displayScale, 1)
        let thick = full > slim * 2.2 ? 6 : full
        let top = max((bounds.height - thick) / 2, 0)
        trackLayer.frame = CGRect(x: pad, y: top, width: max(bounds.width - pad * 2, 0), height: thick)
        trackLayer.backgroundColor = trackColor.cgColor
        trackLayer.cornerRadius = thick / 2
        let inner = max(bounds.width - pad * 2, 0)
        let width = inner * max(to - from, 0)
        let target = CGRect(x: pad + from * inner, y: top, width: width, height: thick)
        barLayer.backgroundColor = barColor.cgColor
        barLayer.cornerRadius = thick / 2
        if animate && shown != width {
            barLayer.frame = CGRect(x: target.minX, y: top, width: shown, height: thick)
            UIView.animate(withDuration: 0.3) { self.barLayer.frame = target }
        } else {
            barLayer.frame = target
        }
        shown = width
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { seek(touches, settled: false) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { seek(touches, settled: false) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { seek(touches, settled: true) }
    private func seek(_ touches: Set<UITouch>, settled: Bool) {
        guard seekable, let x = touches.first?.location(in: self).x else { return }
        let pad: CGFloat = 1
        let inner = max(bounds.width - pad * 2, 1)
        let fraction = min(max((x - pad) / inner, 0), 1)
        animate = false
        bind(from: 0, to: fraction, animate: false)
        onSeek?(fraction, settled)
    }
}

public protocol OTLottiePlaying: AnyObject {
    func setPlaying(_ playing: Bool)
}

final class OTLottieView: UIView, OTLottiePlaying {
    private var player: OTLottieHost = OTLottieFallback()
    override init(frame: CGRect) {
        super.init(frame: frame)
        #if canImport(Lottie)
        let host = OTLottieLottie()
        player = host
        host.view.frame = bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(host.view)
        #endif
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func bind(src: String, repeatCount: String, mode: String, autoPlay: Bool) {
        player.bind(src: src, repeatCount: repeatCount, mode: mode, autoPlay: autoPlay)
    }
    func setPlaying(_ playing: Bool) { player.setPlaying(playing) }
    func releaseAnimation() { player.releaseAnimation() }
}

protocol OTLottieHost: OTLottiePlaying {
    func bind(src: String, repeatCount: String, mode: String, autoPlay: Bool)
    func releaseAnimation()
}

final class OTLottieFallback: OTLottieHost {
    func bind(src: String, repeatCount: String, mode: String, autoPlay: Bool) {}
    func setPlaying(_ playing: Bool) {}
    func releaseAnimation() {}
}

#if canImport(Lottie)
import Lottie
final class OTLottieLottie: OTLottieHost {
    let view = LottieAnimationView()
    func bind(src: String, repeatCount: String, mode: String, autoPlay: Bool) {
        view.stop()
        view.loopMode = loop(repeatCount, mode)
        let play = {
            if autoPlay { self.view.play() }
        }
        if src.hasPrefix("http://") || src.hasPrefix("https://"), let url = URL(string: src) {
            LottieAnimation.loadedFrom(url: url) { [weak view] animation in
                view?.animation = animation
                play()
            }
            return
        }
        if src.hasPrefix("assets:") {
            var path = String(src.dropFirst("assets:".count))
            if !path.hasSuffix(".json") { path += ".json" }
            if let file = OTAssets.file(path) {
                view.animation = LottieAnimation.filepath(file.path)
                let folder = file.deletingLastPathComponent().appendingPathComponent("images")
                if FileManager.default.fileExists(atPath: folder.path) {
                    view.imageProvider = FilepathImageProvider(filepath: folder.path)
                }
                play()
            }
        }
    }
    func setPlaying(_ playing: Bool) {
        if playing { view.play() } else { view.pause() }
    }
    func releaseAnimation() { view.stop() }
    private func loop(_ count: String, _ mode: String) -> LottieLoopMode {
        let reverse = mode.lowercased() == "reverse"
        if count.lowercased() == "infinite" {
            return reverse ? .autoReverse : .loop
        }
        let times = Float(count) ?? 0
        return reverse ? .repeatBackwards(times) : .repeat(times)
    }
}
#endif

final class OTListView: UICollectionView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    let flow: UICollectionViewFlowLayout
    var items = JSONArray()
    var dataKey: String?
    var itemTemplate: ParsedNode?
    var gap: CGFloat = 0
    var horizontal = false
    var windowWidth: CGFloat = 0
    weak var template: OTTemplateContext?
    init() {
        let flow = UICollectionViewFlowLayout()
        flow.minimumInteritemSpacing = 0
        self.flow = flow
        super.init(frame: .zero, collectionViewLayout: flow)
        backgroundColor = .clear
        dataSource = self
        delegate = self
        register(OTListCell.self, forCellWithReuseIdentifier: "item")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func apply(direction: String, gap: CGFloat) {
        horizontal = direction == TemplateKey.horizontal
        self.gap = gap
        flow.scrollDirection = horizontal ? .horizontal : .vertical
        flow.minimumLineSpacing = gap
    }
    func setItems(_ array: JSONArray, key: String?) {
        items = array
        dataKey = key
        reloadData()
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.size }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "item", for: indexPath) as! OTListCell
        guard let templateNode = itemTemplate, let template else { return cell }
        let data = items.getJSONObject(indexPath.item) ?? JSONObject()
        let size = itemSize(data, templateNode)
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        guard let laid = try? OTLayoutCall.layout(root: templateNode, data: data, viewport: size.viewport, windowWidth: windowWidth),
              let view = try? OTViewTree.build(parsed: templateNode, laid: laid, template: template, itemData: data) else { return cell }
        view.frame = CGRect(origin: .zero, size: laid.frame.size)
        cell.contentView.addSubview(view)
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let templateNode = itemTemplate else { return CGSize(width: max(bounds.width, 1), height: 44) }
        let data = items.getJSONObject(indexPath.item)
        return itemSize(data, templateNode).item
    }
    private func itemSize(_ data: JSONObject?, _ templateNode: ParsedNode) -> (viewport: CGSize, item: CGSize) {
        let free: CGFloat = 8192
        let viewport = horizontal
            ? CGSize(width: free, height: max(bounds.height, 1))
            : CGSize(width: max(bounds.width, 1), height: free)
        guard let laid = try? OTLayoutCall.layout(root: templateNode, data: data, viewport: viewport, windowWidth: windowWidth) else {
            return (viewport, CGSize(width: max(bounds.width, 1), height: 44))
        }
        return (viewport, CGSize(width: max(laid.frame.width, 1), height: max(laid.frame.height, 1)))
    }
    var firstScroll: (index: Int, offset: CGFloat)? {
        guard let index = indexPathsForVisibleItems.sorted().first,
              let attr = layoutAttributesForItem(at: index) else { return nil }
        let delta = horizontal ? attr.frame.minX - contentOffset.x : attr.frame.minY - contentOffset.y
        return (index.item, delta)
    }
    func restoreScroll(index: Int, offset: CGFloat) {
        guard index >= 0, index < items.size else { return }
        layoutIfNeeded()
        let path = IndexPath(item: index, section: 0)
        guard let attr = layoutAttributesForItem(at: path) else { return }
        if horizontal {
            contentOffset.x = attr.frame.minX - offset
        } else {
            contentOffset.y = attr.frame.minY - offset
        }
    }
}

final class OTListCell: UICollectionViewCell {}

enum OTIme {
    static func dismiss(_ view: UIView) {
        view.endEditing(true)
    }
    static func install(on view: UIView) {
        let tap = UITapGestureRecognizer(target: DismissTarget.shared, action: #selector(DismissTarget.dismiss(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = DismissTarget.shared
        view.addGestureRecognizer(tap)
    }
    final class DismissTarget: NSObject, UIGestureRecognizerDelegate {
        static let shared = DismissTarget()
        @objc func dismiss(_ gesture: UITapGestureRecognizer) {
            guard let root = gesture.view else { return }
            let point = gesture.location(in: root)
            if hitInput(root, point) { return }
            root.endEditing(true)
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView { return false }
                view = current.superview
            }
            return true
        }
        private func hitInput(_ view: UIView, _ point: CGPoint) -> Bool {
            let local = view.convert(point, from: view)
            if (view is UITextField || view is UITextView), view.bounds.contains(view.convert(point, from: view.superview ?? view)) {
                return true
            }
            for child in view.subviews where hitInput(child, point) { return true }
            _ = local
            return false
        }
    }
}

enum OTToast {
    static func show(_ message: String, in view: UIView?) {
        guard let host = view?.window ?? view else { return }
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.backgroundColor = UIColor(white: 0.15, alpha: 0.92)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        let width = min(host.bounds.width - 48, 280)
        let size = label.sizeThatFits(CGSize(width: width - 24, height: 200))
        label.frame = CGRect(x: (host.bounds.width - width) / 2, y: host.bounds.height - 120, width: width, height: size.height + 16)
        host.addSubview(label)
        UIView.animate(withDuration: 0.25, delay: 1.6, options: []) {
            label.alpha = 0
        } completion: { _ in
            label.removeFromSuperview()
        }
    }
}
