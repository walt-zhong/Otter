package com.dynamic.otter.permission

import com.alibaba.fastjson.JSONObject

object PermissionFields {
    fun prefix(capability: String): String? {
        return when (capability) {
            PermissionCapability.CAMERA -> "camera"
            PermissionCapability.MICROPHONE -> "microphone"
            PermissionCapability.LOCATION_WHEN_IN_USE -> "location"
            PermissionCapability.PHOTOS -> "photos"
            PermissionCapability.NOTIFICATIONS -> "notifications"
            else -> null
        }
    }

    fun write(data: JSONObject, result: PermissionResult) {
        val key = prefix(result.capability) ?: return
        data["${key}Status"] = result.status
        data["${key}StatusText"] = result.statusText()
        data["${key}ShowSettings"] = result.showSettings
        if (result.capability != PermissionCapability.PHOTOS) {
            return
        }
        if (result.status == PermissionStatus.GRANTED && result.detail.startsWith("content:")) {
            data["photoSrc"] = result.detail
            data["avatar"] = result.detail
            data["photoVisible"] = true
        }
    }

    fun preservingPhoto(data: JSONObject, result: PermissionResult): PermissionResult {
        if (result.capability != PermissionCapability.PHOTOS) {
            return result
        }
        if (result.status == PermissionStatus.GRANTED && result.detail.startsWith("content:")) {
            return result
        }
        val saved = sequenceOf(data.getString("photoSrc"), data.getString("avatar"))
            .firstOrNull { !it.isNullOrBlank() && it.startsWith("content:") }
            ?: return result
        return result.copy(
            status = PermissionStatus.GRANTED,
            canAskAgain = true,
            asked = true,
            detail = saved
        )
    }
}
