import UIKit

/// One container for an Android `PageStack`. System edge-back is the stack's
/// own gesture while more than one page is showing. At the root page, the
/// navigation controller pops this screen, which is the activity finish.
///
/// Process death: `encodeRestorableState` / the scene activity store the same
/// JSON `PageStack.exportState` produces. iOS has no `Bundle` transaction cap;
/// the stack still drops payloads over 200_000 characters and reopens `start`.
/// If UIKit does not hand the activity back, nothing is restored and `start` opens.
/// That is not a successful restore.
class StackController: UIViewController {
    let route: String
    let bizId: String
    let templateId: String
    let container = UIView()
    private(set) var stack: PageStack?
    private var pendingState: String?

    init(route: String, bizId: String, templateId: String) {
        self.route = route
        self.bizId = bizId
        self.templateId = templateId
        super.init(nibName: nil, bundle: nil)
        restorationIdentifier = "otter.stack.\(templateId)"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.addSubview(container)
        OTIme.install(on: view)
        do {
            let attached = try PageStack.attach(host: self, insetRoot: view, container: container, routePath: route, bizId: bizId, templateId: templateId)
            if let pendingState { attached.restoreState(pendingState) }
            stack = attached
        } catch {
            OTToast.show(error.localizedDescription, in: view)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        container.frame = view.bounds
        stack?.layoutContainers()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        stack?.activate()
    }

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        if let text = stack?.exportState() {
            coder.encode(text, forKey: "otter.pages")
        }
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        let text = coder.decodeObject(forKey: "otter.pages") as? String
        if let stack {
            stack.restoreState(text)
        } else {
            pendingState = text
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            stack?.releaseStack()
            stack = nil
        }
    }
}

final class PermissionController: StackController {
    private var permissions: OTPermissionCenter?
    init() {
        super.init(route: "templates/permission/routes.json", bizId: "demo", templateId: "permission")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        permissions = OTPermissionCenter.install(host: self)
        super.viewDidLoad()
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed { permissions?.releaseCenter() }
    }
}
