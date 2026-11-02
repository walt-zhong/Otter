import OtterCore
import OtterLayout
import UIKit

public final class OTTemplateContext {
    public let bizId: String
    public let templateId: String
    public let templatePath: String
    public var data: JSONObject?
    public var events: [String: JSONObject] = [:]
    public var parsed: ParsedTemplate?
    public weak var rootView: UIView?
    public var viewport: CGSize = .zero
    public var scale: CGFloat = 1
    public var viewIds: [String: UIView] = [:]
    public var laidOut: OTLaidOutNode?
    init(bizId: String, templateId: String, templatePath: String) {
        self.bizId = bizId
        self.templateId = templateId
        self.templatePath = templatePath
    }

    public func release() {
        (rootView as? OTLottieView)?.releaseAnimation()
        releaseTree(rootView)
        rootView?.removeFromSuperview()
        rootView = nil
        parsed = nil
        laidOut = nil
        data = nil
        events = [:]
        viewIds = [:]
    }

    private func releaseTree(_ view: UIView?) {
        guard let view else { return }
        if let image = view as? OTImageView { image.releaseImage() }
        if let lottie = view as? OTLottieView { lottie.releaseAnimation() }
        for child in view.subviews { releaseTree(child) }
    }
}

public final class OTEngine {
    public static let shared = OTEngine()

    public func buildTemplate(bizId: String, templateId: String, templatePath: String) -> OTTemplateContext {
        OTTemplateContext(bizId: bizId, templateId: templateId, templatePath: templatePath)
    }

    public func setData(_ template: OTTemplateContext, _ json: String) throws {
        template.data = try OTData.parseObject(json)
    }

    public func createView(_ template: OTTemplateContext, viewport: CGSize) throws -> UIView {
        let json = try OTAssets.text(template.templatePath)
        let parsed = try TemplateJsonParser.parse(json)
        template.parsed = parsed
        template.events = parsed.events
        template.viewport = viewport
        template.scale = CGFloat(ScreenAdapt.scaleFor(Float(viewport.width)))
        template.viewIds = [:]
        let laid = try OTLayoutCall.layout(root: parsed.root, data: template.data, viewport: viewport, windowWidth: viewport.width)
        template.laidOut = laid
        let view = try OTViewTree.build(parsed: parsed.root, laid: laid, template: template, itemData: nil)
        view.frame = CGRect(origin: .zero, size: viewport)
        template.rootView = view
        return view
    }

    public func relayout(_ template: OTTemplateContext, viewport: CGSize) {
        guard let parsed = template.parsed, let root = template.rootView else { return }
        template.viewport = viewport
        template.scale = CGFloat(ScreenAdapt.scaleFor(Float(viewport.width)))
        guard let laid = try? OTLayoutCall.layout(root: parsed.root, data: template.data, viewport: viewport, windowWidth: viewport.width) else { return }
        template.laidOut = laid
        root.frame = CGRect(origin: .zero, size: viewport)
        OTViewTree.applyFrames(view: root, laid: laid)
        root.frame = CGRect(origin: .zero, size: viewport)
    }

    public func rebind(_ template: OTTemplateContext) throws {
        guard let parsed = template.parsed, let root = template.rootView else { return }
        let saved = template.viewIds
        let viewport = template.viewport
        let laid: OTLaidOutNode
        do {
            laid = try OTLayoutCall.layout(root: parsed.root, data: template.data, viewport: viewport, windowWidth: viewport.width)
        } catch {
            template.viewIds = saved
            throw error
        }
        template.viewIds = [:]
        template.laidOut = laid
        try OTViewTree.rebind(view: root, parsed: parsed.root, laid: laid, template: template)
        OTViewTree.applyFrames(view: root, laid: laid)
    }

    public func release(_ template: OTTemplateContext) {
        template.release()
    }
}
