package com.dynamic.otter.permission

object PermissionCapability {
    const val CAMERA = "camera"
    const val MICROPHONE = "microphone"
    const val LOCATION_WHEN_IN_USE = "location.whenInUse"
    const val PHOTOS = "photos"
    const val NOTIFICATIONS = "notifications"

    val all: List<String> = listOf(
        CAMERA,
        MICROPHONE,
        LOCATION_WHEN_IN_USE,
        PHOTOS,
        NOTIFICATIONS
    )
}

object PermissionStatus {
    const val GRANTED = "granted"
    const val DENIED = "denied"
    const val LIMITED = "limited"
    const val PERMANENTLY_DENIED = "permanentlyDenied"
    const val RESTRICTED = "restricted"
    const val UNSUPPORTED = "unsupported"
}
