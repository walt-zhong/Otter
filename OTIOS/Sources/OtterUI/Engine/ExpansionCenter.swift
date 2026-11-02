import OtterCore
import UIKit

public final class ExpansionCenter {
    public static let shared = ExpansionCenter()
    public var pageOpener: ((UIViewController, String) -> Void)?
    public var itemClick: (([String: String]) -> Void)?
    private var hostActions: [String: (UIView, JSONObject?) -> Void] = [:]

    public func registerPageOpener(_ opener: @escaping (UIViewController, String) -> Void) {
        pageOpener = opener
    }

    public func registerHostAction(_ name: String, _ action: @escaping (UIView, JSONObject?) -> Void) {
        hostActions[name] = action
    }

    @discardableResult
    public func dispatchHost(_ view: UIView, _ name: String, _ params: JSONObject?) -> Bool {
        guard let action = hostActions[name] else { return false }
        action(view, params)
        return true
    }
}
