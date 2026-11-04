package com.dynamic.otter.permission

internal object PermissionJudge {
    fun single(
        capability: String,
        granted: Boolean,
        asked: Boolean,
        shouldShowRationale: Boolean
    ): PermissionResult {
        if (granted) {
            return PermissionResult(
                capability = capability,
                status = PermissionStatus.GRANTED,
                canAskAgain = false,
                asked = asked
            )
        }
        if (!asked || shouldShowRationale) {
            return PermissionResult(
                capability = capability,
                status = PermissionStatus.DENIED,
                canAskAgain = true,
                asked = asked
            )
        }
        return PermissionResult(
            capability = capability,
            status = PermissionStatus.PERMANENTLY_DENIED,
            canAskAgain = false,
            asked = true
        )
    }

    fun location(
        fineGranted: Boolean,
        coarseGranted: Boolean,
        asked: Boolean,
        fineShouldShow: Boolean,
        coarseShouldShow: Boolean
    ): PermissionResult {
        if (fineGranted) {
            return PermissionResult(
                capability = PermissionCapability.LOCATION_WHEN_IN_USE,
                status = PermissionStatus.GRANTED,
                canAskAgain = false,
                asked = asked,
                detail = "precise"
            )
        }
        if (coarseGranted) {
            val canUpgrade = !asked || fineShouldShow
            return PermissionResult(
                capability = PermissionCapability.LOCATION_WHEN_IN_USE,
                status = PermissionStatus.LIMITED,
                canAskAgain = canUpgrade,
                asked = asked,
                detail = "approximate"
            )
        }
        return single(
            PermissionCapability.LOCATION_WHEN_IN_USE,
            granted = false,
            asked = asked,
            shouldShowRationale = fineShouldShow || coarseShouldShow
        )
    }

    fun notifications(
        requiresRuntime: Boolean,
        granted: Boolean,
        asked: Boolean,
        shouldShowRationale: Boolean
    ): PermissionResult {
        if (!requiresRuntime) {
            return PermissionResult(
                capability = PermissionCapability.NOTIFICATIONS,
                status = PermissionStatus.GRANTED,
                canAskAgain = false,
                asked = false
            )
        }
        return single(
            PermissionCapability.NOTIFICATIONS,
            granted = granted,
            asked = asked,
            shouldShowRationale = shouldShowRationale
        )
    }

    fun photos(asked: Boolean): PermissionResult {
        return PermissionResult(
            capability = PermissionCapability.PHOTOS,
            status = PermissionStatus.DENIED,
            canAskAgain = true,
            asked = asked
        )
    }

    fun grantedPhoto(uri: String): PermissionResult {
        return PermissionResult(
            capability = PermissionCapability.PHOTOS,
            status = PermissionStatus.GRANTED,
            canAskAgain = true,
            asked = true,
            detail = uri
        )
    }

    fun unsupported(capability: String): PermissionResult {
        return PermissionResult(
            capability = capability,
            status = PermissionStatus.UNSUPPORTED,
            canAskAgain = false,
            asked = false
        )
    }
}
