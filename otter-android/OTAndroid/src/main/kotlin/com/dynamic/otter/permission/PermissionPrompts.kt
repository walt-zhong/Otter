package com.dynamic.otter.permission

object PermissionPrompts {
    fun standard(): Map<String, PermissionPrompt> {
        return mapOf(
            PermissionCapability.CAMERA to PermissionPrompt(
                "相机",
                "用来拍照。接下来会弹出系统对话框，你可以拒绝。"
            ),
            PermissionCapability.MICROPHONE to PermissionPrompt(
                "麦克风",
                "用来录音。接下来会弹出系统对话框，你可以拒绝。"
            ),
            PermissionCapability.LOCATION_WHEN_IN_USE to PermissionPrompt(
                "位置",
                "只在使用时获取位置，不会在后台定位。你可以只给大致位置。"
            ),
            PermissionCapability.PHOTOS to PermissionPrompt(
                "相册",
                "接下来打开系统选图。只会拿到你选中的那张，不会读取整个相册。"
            ),
            PermissionCapability.NOTIFICATIONS to PermissionPrompt(
                "通知",
                "用来发送通知。接下来会弹出系统对话框，你可以拒绝。"
            )
        )
    }
}
