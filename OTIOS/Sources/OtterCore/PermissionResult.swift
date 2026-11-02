public struct PermissionResult: Equatable {
    public let capability: String
    public let status: String
    public let canAskAgain: Bool
    public let asked: Bool
    public let detail: String

    public init(
        capability: String,
        status: String,
        canAskAgain: Bool,
        asked: Bool,
        detail: String = ""
    ) {
        self.capability = capability
        self.status = status
        self.canAskAgain = canAskAgain
        self.asked = asked
        self.detail = detail
    }

    public var showSettings: Bool {
        status == PermissionStatus.PERMANENTLY_DENIED ||
            (status == PermissionStatus.LIMITED && !canAskAgain)
    }

    public func statusText() -> String {
        if capability == PermissionCapability.PHOTOS {
            switch status {
            case PermissionStatus.GRANTED:
                return "已选好一张"
            case PermissionStatus.UNSUPPORTED:
                return Self.UNSUPPORTED_TEXT
            case PermissionStatus.RESTRICTED:
                return Self.RESTRICTED_TEXT
            default:
                return asked ? "没有选图片" : "还没选过"
            }
        }
        if capability == PermissionCapability.LOCATION_WHEN_IN_USE {
            switch status {
            case PermissionStatus.GRANTED:
                return "已允许，精确位置"
            case PermissionStatus.LIMITED:
                return "只给了大致位置"
            case PermissionStatus.PERMANENTLY_DENIED:
                return Self.PERMANENT_TEXT
            case PermissionStatus.RESTRICTED:
                return Self.RESTRICTED_TEXT
            case PermissionStatus.UNSUPPORTED:
                return Self.UNSUPPORTED_TEXT
            default:
                return asked ? "未允许" : "还没问过"
            }
        }
        switch status {
        case PermissionStatus.GRANTED:
            return "已允许"
        case PermissionStatus.LIMITED:
            return "只给了一部分"
        case PermissionStatus.PERMANENTLY_DENIED:
            return Self.PERMANENT_TEXT
        case PermissionStatus.RESTRICTED:
            return Self.RESTRICTED_TEXT
        case PermissionStatus.UNSUPPORTED:
            return Self.UNSUPPORTED_TEXT
        default:
            return asked ? "未允许" : "还没问过"
        }
    }

    private static let PERMANENT_TEXT = "已关闭，要到系统设置里打开"
    private static let RESTRICTED_TEXT = "被系统限制"
    private static let UNSUPPORTED_TEXT = "当前版本没有这项"
}

public struct PermissionPrompt: Equatable {
    public let title: String
    public let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}
