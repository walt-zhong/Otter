import OtterCore
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let nav = UINavigationController(rootViewController: HomeController())
        nav.isNavigationBarHidden = true
        window.rootViewController = nav
        self.window = window
        window.makeKeyAndVisible()
        ExpansionCenter.shared.registerPageOpener { controller, page in
            DemoRoutes.open(controller, page)
        }
    }
}

enum DemoRoutes {
    static func open(_ controller: UIViewController, _ page: String) {
        let next: UIViewController?
        switch page {
        case "stack":
            next = StackController(route: "templates/stack/routes.json", bizId: "demo", templateId: "stack")
        case "permission":
            next = PermissionController()
        case "market":
            next = MarketController()
        case "weather":
            next = TemplateController(template: "templates/weather/weather.json", data: "templates/weather/mock-data/weather.json", bizId: "demo", templateId: "weather")
        default:
            guard let spec = components[page] else {
                OTToast.show("没有这个示例", in: controller.view)
                return
            }
            next = TemplateController(template: spec.0, data: spec.1, bizId: "demo", templateId: page)
        }
        guard let next else { return }
        if let nav = controller.navigationController {
            nav.pushViewController(next, animated: true)
        } else {
            controller.present(next, animated: true)
        }
    }

    private static let components: [String: (String, String)] = [
        "column": ("templates/column/column.json", "templates/column/mock-data/column.json"),
        "row": ("templates/row/row.json", "templates/row/mock-data/row.json"),
        "text": ("templates/text/text.json", "templates/text/mock-data/text.json"),
        "image": ("templates/image/image.json", "templates/image/mock-data/image.json"),
        "spacer": ("templates/spacer/spacer.json", "templates/spacer/mock-data/spacer.json"),
        "list": ("templates/list/list.json", "templates/list/mock-data/list.json"),
        "progress": ("templates/progress/progress.json", "templates/progress/mock-data/progress.json"),
        "lottie": ("templates/lottie/lottie.json", "templates/lottie/mock-data/lottie.json"),
        "input": ("templates/input/input.json", "templates/input/mock-data/input.json"),
        "checkbox": ("templates/checkbox/checkbox.json", "templates/checkbox/mock-data/checkbox.json"),
        "radio": ("templates/radio/radio.json", "templates/radio/mock-data/radio.json"),
        "switch": ("templates/switch/switch.json", "templates/switch/mock-data/switch.json"),
        "inbox": ("templates/inbox/inbox.json", "templates/inbox/mock-data/inbox.json"),
        "journey": ("templates/journey/journey.json", "templates/journey/mock-data/journey.json"),
        "player": ("templates/player/player.json", "templates/player/mock-data/player.json"),
        "chat": ("templates/chat/chat.json", "templates/chat/mock-data/chat.json"),
        "glass": ("templates/glass/glass.json", "templates/glass/mock-data/glass.json")
    ]
}

final class HomeController: TemplateController {
    init() {
        super.init(template: "templates/home-demo/home.json", data: "templates/home-demo/mock-data/home.json", bizId: "demo", templateId: "home")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

class TemplateController: UIViewController {
    let templatePath: String
    let dataPath: String
    let bizId: String
    let templateId: String
    private var template: OTTemplateContext?
    private let host = UIView()
    private var built = false

    init(template: String, data: String, bizId: String, templateId: String) {
        self.templatePath = template
        self.dataPath = data
        self.bizId = bizId
        self.templateId = templateId
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        host.backgroundColor = .clear
        view.addSubview(host)
        OTIme.install(on: view)
        let context = OTEngine.shared.buildTemplate(bizId: bizId, templateId: templateId, templatePath: templatePath)
        template = context
        do {
            try OTEngine.shared.setData(context, try OTAssets.text(dataPath))
        } catch {
            OTToast.show(error.localizedDescription, in: view)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.safeAreaInsets
        host.frame = view.bounds.inset(by: UIEdgeInsets(top: safe.top, left: safe.left, bottom: safe.bottom, right: safe.right))
        guard let template, host.bounds.width > 0, host.bounds.height > 0 else { return }
        if !built {
            built = true
            do {
                let builtView = try OTEngine.shared.createView(template, viewport: host.bounds.size)
                builtView.frame = host.bounds
                builtView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                host.addSubview(builtView)
            } catch {
                OTToast.show(error.localizedDescription, in: view)
            }
            return
        }
        if template.viewport != host.bounds.size {
            OTEngine.shared.relayout(template, viewport: host.bounds.size)
            template.rootView?.frame = host.bounds
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            if let template { OTEngine.shared.release(template) }
        }
    }
}
