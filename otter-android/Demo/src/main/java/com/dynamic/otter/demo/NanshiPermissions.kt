package com.dynamic.otter.demo

import com.dynamic.otter.permission.PermissionCapability
import com.dynamic.otter.permission.PermissionPrompt

object NanshiPermissions {
    val prompts: Map<String, PermissionPrompt> = mapOf(
        PermissionCapability.CAMERA to PermissionPrompt(
            "拍菜单",
            "南市想用相机，拍下黑板上的字。这次只确认允不允许，还不会打开相机。"
        ),
        PermissionCapability.MICROPHONE to PermissionPrompt(
            "留一句",
            "南市想用麦克风，留一句给店员。这次只确认允不允许，还不会录音。"
        ),
        PermissionCapability.LOCATION_WHEN_IN_USE to PermissionPrompt(
            "走到巷口",
            "只在你查看南市时使用位置，用来判断你在不在这条巷。不会在后台定位。你可以只给大致位置。"
        ),
        PermissionCapability.PHOTOS to PermissionPrompt(
            "换头像",
            "从相册选一张做头像。只会拿到你点中的那张，不会读取整个相册。"
        ),
        PermissionCapability.NOTIFICATIONS to PermissionPrompt(
            "取餐通知",
            "摊位做好了就通知你。接下来会弹出系统对话框，你可以拒绝。"
        )
    )
}
