package com.dynamic.otter.permission

data class PermissionResult(
    val capability: String,
    val status: String,
    val canAskAgain: Boolean,
    val asked: Boolean,
    val detail: String = ""
) {
    val showSettings: Boolean
        get() = status == PermissionStatus.PERMANENTLY_DENIED ||
            (status == PermissionStatus.LIMITED && !canAskAgain)

    fun statusText(): String {
        if (capability == PermissionCapability.PHOTOS) {
            return when (status) {
                PermissionStatus.GRANTED -> "已选好一张"
                PermissionStatus.UNSUPPORTED -> UNSUPPORTED_TEXT
                PermissionStatus.RESTRICTED -> RESTRICTED_TEXT
                else -> if (asked) "没有选图片" else "还没选过"
            }
        }
        if (capability == PermissionCapability.LOCATION_WHEN_IN_USE) {
            return when (status) {
                PermissionStatus.GRANTED -> "已允许，精确位置"
                PermissionStatus.LIMITED -> "只给了大致位置"
                PermissionStatus.PERMANENTLY_DENIED -> PERMANENT_TEXT
                PermissionStatus.RESTRICTED -> RESTRICTED_TEXT
                PermissionStatus.UNSUPPORTED -> UNSUPPORTED_TEXT
                else -> if (asked) "未允许" else "还没问过"
            }
        }
        return when (status) {
            PermissionStatus.GRANTED -> "已允许"
            PermissionStatus.LIMITED -> "只给了一部分"
            PermissionStatus.PERMANENTLY_DENIED -> PERMANENT_TEXT
            PermissionStatus.RESTRICTED -> RESTRICTED_TEXT
            PermissionStatus.UNSUPPORTED -> UNSUPPORTED_TEXT
            else -> if (asked) "未允许" else "还没问过"
        }
    }

    private companion object {
        const val PERMANENT_TEXT = "已关闭，要到系统设置里打开"
        const val RESTRICTED_TEXT = "被系统限制"
        const val UNSUPPORTED_TEXT = "当前版本没有这项"
    }
}

data class PermissionPrompt(
    val title: String,
    val message: String
)
