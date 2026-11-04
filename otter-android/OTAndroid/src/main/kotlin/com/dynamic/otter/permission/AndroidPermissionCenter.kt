package com.dynamic.otter.permission

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner

class AndroidPermissionCenter private constructor(
    private val activity: ComponentActivity,
    private val prompts: Map<String, PermissionPrompt>
) {
    private var released = false
    private var inFlight = false
    private var dialog: AlertDialog? = null
    private var pending: ((PermissionResult) -> Unit)? = null
    private var pendingCapability: String? = null

    private val permissionLauncher = activity.registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) {
        val capability = pendingCapability ?: prefs().getString(PENDING_KEY, null)
            ?: return@registerForActivityResult
        markAsked(capability)
        finish(check(capability))
    }

    private val photoLauncher = activity.registerForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        markAsked(PermissionCapability.PHOTOS)
        val result = if (uri == null) {
            PermissionJudge.photos(asked = true)
        } else {
            PermissionJudge.grantedPhoto(uri.toString())
        }
        finish(result)
    }

    private val settingsLauncher = activity.registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) {
        val capability = pendingCapability ?: prefs().getString(PENDING_KEY, null)
            ?: return@registerForActivityResult
        finish(check(capability))
    }

    init {
        activity.lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onDestroy(owner: LifecycleOwner) {
                release()
            }
        })
    }

    fun check(capability: String): PermissionResult {
        if (capability == PermissionCapability.PHOTOS) {
            return PermissionJudge.photos(asked(capability))
        }
        if (capability !in PermissionCapability.all || !hardware(capability)) {
            return PermissionJudge.unsupported(capability)
        }
        if (capability == PermissionCapability.NOTIFICATIONS && Build.VERSION.SDK_INT < 33) {
            return PermissionJudge.notifications(
                requiresRuntime = false,
                granted = true,
                asked = false,
                shouldShowRationale = false
            )
        }
        val permissions = runtimePermissions(capability)
        if (permissions.isNullOrEmpty() || permissions.any { !declared(it) }) {
            return PermissionJudge.unsupported(capability)
        }
        if (capability == PermissionCapability.LOCATION_WHEN_IN_USE) {
            return PermissionJudge.location(
                fineGranted = granted(Manifest.permission.ACCESS_FINE_LOCATION),
                coarseGranted = granted(Manifest.permission.ACCESS_COARSE_LOCATION),
                asked = asked(capability),
                fineShouldShow = rationale(Manifest.permission.ACCESS_FINE_LOCATION),
                coarseShouldShow = rationale(Manifest.permission.ACCESS_COARSE_LOCATION)
            )
        }
        val permission = permissions.first()
        val requiresRuntime = capability == PermissionCapability.NOTIFICATIONS
        if (requiresRuntime) {
            return PermissionJudge.notifications(
                requiresRuntime = true,
                granted = granted(permission),
                asked = asked(capability),
                shouldShowRationale = rationale(permission)
            )
        }
        return PermissionJudge.single(
            capability,
            granted = granted(permission),
            asked = asked(capability),
            shouldShowRationale = rationale(permission)
        )
    }

    fun request(capability: String, onResult: (PermissionResult) -> Unit) {
        if (inFlight || !alive()) {
            return
        }
        val current = check(capability)
        if (!shouldPrompt(current)) {
            onResult(current)
            return
        }
        val prompt = prompts[capability] ?: PermissionPrompt(
            "权限",
            "接下来会弹出系统对话框，你可以拒绝。"
        )
        inFlight = true
        val created = AlertDialog.Builder(activity)
            .setTitle(prompt.title)
            .setMessage(prompt.message)
            .setPositiveButton("继续") { _, _ ->
                launch(capability, onResult)
            }
            .setNegativeButton("先不用", null)
            .create()
        created.setOnDismissListener {
            if (pending == null) {
                inFlight = false
            }
            if (dialog === created) {
                dialog = null
            }
        }
        dialog = created
        created.show()
    }

    fun openSettings(capability: String, onResult: (PermissionResult) -> Unit) {
        if (inFlight || !alive()) {
            return
        }
        inFlight = true
        pending = onResult
        pendingCapability = capability
        prefs().edit().putString(PENDING_KEY, capability).apply()
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", activity.packageName, null)
        }
        try {
            settingsLauncher.launch(intent)
        } catch (_: Exception) {
            finish(check(capability))
        }
    }

    fun release() {
        if (released) {
            return
        }
        released = true
        val showing = dialog
        dialog = null
        pending = null
        pendingCapability = null
        inFlight = false
        showing?.setOnDismissListener(null)
        showing?.dismiss()
        installed.remove(activity)
    }

    private fun launch(capability: String, onResult: (PermissionResult) -> Unit) {
        if (!alive()) {
            inFlight = false
            return
        }
        pending = onResult
        pendingCapability = capability
        prefs().edit().putString(PENDING_KEY, capability).apply()
        try {
            if (capability == PermissionCapability.PHOTOS) {
                photoLauncher.launch(
                    PickVisualMediaRequest.Builder()
                        .setMediaType(ActivityResultContracts.PickVisualMedia.ImageOnly)
                        .build()
                )
                return
            }
            val permissions = runtimePermissions(capability)
            if (permissions.isNullOrEmpty()) {
                finish(check(capability))
                return
            }
            permissionLauncher.launch(permissions.toTypedArray())
        } catch (_: Exception) {
            finish(check(capability))
        }
    }

    private fun finish(result: PermissionResult) {
        val callback = pending
        pending = null
        pendingCapability = null
        inFlight = false
        if (!alive()) {
            return
        }
        prefs().edit().remove(PENDING_KEY).apply()
        if (callback != null) {
            callback(result)
        } else {
            PermissionActions.publish(activity, result)
        }
    }

    private fun shouldPrompt(current: PermissionResult): Boolean {
        if (current.status == PermissionStatus.UNSUPPORTED ||
            current.status == PermissionStatus.RESTRICTED ||
            current.status == PermissionStatus.GRANTED ||
            current.status == PermissionStatus.PERMANENTLY_DENIED
        ) {
            return false
        }
        if (current.status == PermissionStatus.LIMITED && !current.canAskAgain) {
            return false
        }
        return current.canAskAgain
    }

    private fun runtimePermissions(capability: String): List<String>? {
        return when (capability) {
            PermissionCapability.CAMERA -> listOf(Manifest.permission.CAMERA)
            PermissionCapability.MICROPHONE -> listOf(Manifest.permission.RECORD_AUDIO)
            PermissionCapability.LOCATION_WHEN_IN_USE -> listOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
            PermissionCapability.NOTIFICATIONS -> {
                if (Build.VERSION.SDK_INT < 33) {
                    emptyList()
                } else {
                    listOf(Manifest.permission.POST_NOTIFICATIONS)
                }
            }
            else -> null
        }
    }

    private fun hardware(capability: String): Boolean {
        val manager = activity.packageManager
        return when (capability) {
            PermissionCapability.CAMERA -> manager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)
            PermissionCapability.MICROPHONE -> manager.hasSystemFeature(PackageManager.FEATURE_MICROPHONE)
            PermissionCapability.LOCATION_WHEN_IN_USE -> manager.hasSystemFeature(PackageManager.FEATURE_LOCATION)
            else -> true
        }
    }

    private fun declared(permission: String): Boolean {
        val info = try {
            @Suppress("DEPRECATION")
            activity.packageManager.getPackageInfo(
                activity.packageName,
                PackageManager.GET_PERMISSIONS
            )
        } catch (_: Exception) {
            return false
        }
        return info.requestedPermissions?.contains(permission) == true
    }

    private fun granted(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(activity, permission) == PackageManager.PERMISSION_GRANTED
    }

    private fun rationale(permission: String): Boolean {
        return ActivityCompat.shouldShowRequestPermissionRationale(activity, permission)
    }

    private fun asked(capability: String): Boolean {
        return prefs().getBoolean(capability, false)
    }

    private fun markAsked(capability: String) {
        prefs().edit().putBoolean(capability, true).apply()
    }

    private fun prefs() = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun alive(): Boolean {
        return !released && !activity.isFinishing && !activity.isDestroyed
    }

    companion object {
        private const val PREFS = "otter.permission"
        private const val PENDING_KEY = "pending"
        private val installed = mutableMapOf<Activity, AndroidPermissionCenter>()

        fun install(
            activity: ComponentActivity,
            prompts: Map<String, PermissionPrompt> = PermissionPrompts.standard()
        ): AndroidPermissionCenter {
            installed[activity]?.let { existing ->
                if (!existing.released) {
                    return existing
                }
            }
            PermissionActions.register()
            val created = AndroidPermissionCenter(activity, prompts)
            installed[activity] = created
            return created
        }

        fun find(context: Context): AndroidPermissionCenter? {
            val activity = context.findActivity() ?: return null
            val center = installed[activity] ?: return null
            if (center.released) {
                return null
            }
            return center
        }

        private fun Context.findActivity(): Activity? {
            var current: Context = this
            while (true) {
                if (current is Activity) {
                    return current
                }
                if (current !is ContextWrapper) {
                    return null
                }
                current = current.baseContext
            }
        }
    }
}
