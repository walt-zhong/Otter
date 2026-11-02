public enum PermissionJudge {
    public static func single(
        _ capability: String,
        granted: Bool,
        asked: Bool,
        shouldShowRationale: Bool
    ) -> PermissionResult {
        if granted {
            return PermissionResult(
                capability: capability,
                status: PermissionStatus.GRANTED,
                canAskAgain: false,
                asked: asked
            )
        }
        if !asked || shouldShowRationale {
            return PermissionResult(
                capability: capability,
                status: PermissionStatus.DENIED,
                canAskAgain: true,
                asked: asked
            )
        }
        return PermissionResult(
            capability: capability,
            status: PermissionStatus.PERMANENTLY_DENIED,
            canAskAgain: false,
            asked: true
        )
    }

    public static func location(
        fineGranted: Bool,
        coarseGranted: Bool,
        asked: Bool,
        fineShouldShow: Bool,
        coarseShouldShow: Bool
    ) -> PermissionResult {
        if fineGranted {
            return PermissionResult(
                capability: PermissionCapability.LOCATION_WHEN_IN_USE,
                status: PermissionStatus.GRANTED,
                canAskAgain: false,
                asked: asked,
                detail: "precise"
            )
        }
        if coarseGranted {
            let canUpgrade = !asked || fineShouldShow
            return PermissionResult(
                capability: PermissionCapability.LOCATION_WHEN_IN_USE,
                status: PermissionStatus.LIMITED,
                canAskAgain: canUpgrade,
                asked: asked,
                detail: "approximate"
            )
        }
        return single(
            PermissionCapability.LOCATION_WHEN_IN_USE,
            granted: false,
            asked: asked,
            shouldShowRationale: fineShouldShow || coarseShouldShow
        )
    }

    public static func notifications(
        requiresRuntime: Bool,
        granted: Bool,
        asked: Bool,
        shouldShowRationale: Bool
    ) -> PermissionResult {
        if !requiresRuntime {
            return PermissionResult(
                capability: PermissionCapability.NOTIFICATIONS,
                status: PermissionStatus.GRANTED,
                canAskAgain: false,
                asked: false
            )
        }
        return single(
            PermissionCapability.NOTIFICATIONS,
            granted: granted,
            asked: asked,
            shouldShowRationale: shouldShowRationale
        )
    }

    public static func photos(asked: Bool) -> PermissionResult {
        PermissionResult(
            capability: PermissionCapability.PHOTOS,
            status: PermissionStatus.DENIED,
            canAskAgain: true,
            asked: asked
        )
    }

    public static func grantedPhoto(_ uri: String) -> PermissionResult {
        PermissionResult(
            capability: PermissionCapability.PHOTOS,
            status: PermissionStatus.GRANTED,
            canAskAgain: true,
            asked: true,
            detail: uri
        )
    }

    public static func unsupported(_ capability: String) -> PermissionResult {
        PermissionResult(
            capability: capability,
            status: PermissionStatus.UNSUPPORTED,
            canAskAgain: false,
            asked: false
        )
    }
}
