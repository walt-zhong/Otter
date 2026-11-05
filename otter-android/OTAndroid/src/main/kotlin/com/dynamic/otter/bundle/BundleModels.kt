package com.dynamic.otter.bundle

import java.io.File

enum class BundleFailure {
    NETWORK,
    PUBLIC_KEY,
    TOO_LARGE,
    LAYOUT,
    MANIFEST,
    DIGEST,
    SIGNATURE,
    PARSE,
    PATH,
    IO
}

enum class BundleOrigin {
    DOWNLOAD,
    CACHE
}

enum class BundleFallback {
    NONE,
    LAST_VERIFIED
}

enum class BundleStage {
    FETCH,
    INSTALL
}

class BundleException(
    val failure: BundleFailure,
    message: String,
    cause: Throwable? = null
) : IllegalArgumentException(message, cause)

class BundleDownload(
    val id: String,
    val zip: ByteArray,
    val intent: String? = null,
    val sample: Boolean? = null
)

data class InstalledBundle(
    val id: String,
    val root: File,
    val origin: BundleOrigin,
    val intent: String,
    val sample: Boolean,
    val fellBack: Boolean,
    val failure: BundleFailure?
)

data class BundleRecord(
    val slot: String,
    val id: String?,
    val stage: BundleStage,
    val success: Boolean,
    val failure: BundleFailure?,
    val origin: BundleOrigin?,
    val fellBack: Boolean,
    val bytes: Int,
    val durationMs: Long,
    val atMs: Long
)

data class BundleSnapshot(
    val fetchAttempts: Int,
    val fetchSuccess: Int,
    val installAttempts: Int,
    val installSuccess: Int,
    val freshInstalls: Int,
    val cacheFallbacks: Int,
    val failures: Map<BundleFailure, Int>
) {
    val downloadSuccessRate: Double
        get() = rate(fetchSuccess, fetchAttempts)

    val usableRate: Double
        get() = rate(installSuccess, installAttempts)

    private fun rate(hit: Int, total: Int): Double {
        if (total == 0) {
            return 0.0
        }
        return hit.toDouble() / total
    }
}

fun interface BundleListener {
    fun onRecord(record: BundleRecord)
}
