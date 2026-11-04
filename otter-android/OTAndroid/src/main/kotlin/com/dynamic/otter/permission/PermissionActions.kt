package com.dynamic.otter.permission

import android.content.Context
import android.widget.Toast
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.ExpansionCenter
import com.dynamic.otter.nav.PageStack

object PermissionActions {
    private var registered = false

    fun register() {
        if (registered) {
            return
        }
        registered = true
        val center = ExpansionCenter.instance
        center.registerHostAction(CHECK) { context, params ->
            one(context, params, SettingsMode.CHECK)
        }
        center.registerHostAction(REQUEST) { context, params ->
            one(context, params, SettingsMode.REQUEST)
        }
        center.registerHostAction(OPEN_SETTINGS) { context, params ->
            one(context, params, SettingsMode.SETTINGS)
        }
    }

    fun publishAll(context: Context) {
        val center = AndroidPermissionCenter.find(context) ?: return
        val stack = PageStack.find(context) ?: return
        val results = PermissionCapability.all.map { center.check(it) }
        stack.editCurrentData { data ->
            results.forEach { result ->
                PermissionFields.write(data, PermissionFields.preservingPhoto(data, result))
            }
        }
        stack.rebindCurrent()
    }

    private fun one(context: Context, params: JSONObject?, mode: SettingsMode) {
        val capability = params.string("capability")
        if (capability.isNullOrBlank() || PermissionFields.prefix(capability) == null) {
            toast(context, "没有这项能力")
            return
        }
        val center = AndroidPermissionCenter.find(context)
        if (center == null) {
            toast(context, "这个操作还不能用")
            return
        }
        when (mode) {
            SettingsMode.CHECK -> publish(context, center.check(capability))
            SettingsMode.REQUEST -> center.request(capability) { result ->
                publish(context, result)
            }
            SettingsMode.SETTINGS -> center.openSettings(capability) { result ->
                publish(context, result)
            }
        }
    }

    fun publish(context: Context, result: PermissionResult) {
        val stack = PageStack.find(context) ?: run {
            toast(context, "这个页面还接不上")
            return
        }
        stack.editCurrentData { data ->
            PermissionFields.write(data, PermissionFields.preservingPhoto(data, result))
        }
        stack.rebindCurrent()
    }

    private fun toast(context: Context, message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    private fun JSONObject?.string(key: String): String? {
        if (this == null || !containsKey(key)) {
            return null
        }
        val value = get(key) ?: return null
        return value.toString()
    }

    private enum class SettingsMode {
        CHECK,
        REQUEST,
        SETTINGS
    }

    const val CHECK = "permissionCheck"
    const val REQUEST = "permissionRequest"
    const val OPEN_SETTINGS = "permissionOpenSettings"
}
