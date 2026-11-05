package com.dynamic.otter.bundle

import java.io.File
import java.util.concurrent.CopyOnWriteArrayList

object BundleCenter {
    private val listeners = CopyOnWriteArrayList<BundleListener>()
    private val stats = Stats()

    fun addListener(listener: BundleListener) {
        listeners.addIfAbsent(listener)
    }

    fun removeListener(listener: BundleListener) {
        listeners.remove(listener)
    }

    fun snapshot(): BundleSnapshot {
        return stats.copy()
    }

    fun resetSnapshot() {
        stats.clear()
    }

    fun current(cacheRoot: File, slot: String, publicKey: ByteArray): InstalledBundle? {
        val key = publicKey.copyOf()
        requireKey(key)
        val cached = BundleStore.read(cacheRoot, slot, key) ?: return null
        return installed(cached.opened, cached.root, BundleOrigin.CACHE, fellBack = false, failure = null)
    }

    fun install(
        cacheRoot: File,
        slot: String,
        publicKey: ByteArray,
        zip: ByteArray,
        fallback: BundleFallback = BundleFallback.LAST_VERIFIED
    ): InstalledBundle {
        val key = publicKey.copyOf()
        BundleStore.checkSlot(slot)
        requireKey(key)
        val started = System.nanoTime()
        return try {
            val opened = BundlePackage.open(zip, key)
            val root = BundleStore.commit(cacheRoot, slot, opened)
            val ready = installed(opened, root, BundleOrigin.DOWNLOAD, fellBack = false, failure = null)
            emit(
                record(
                    slot = slot,
                    id = ready.id,
                    stage = BundleStage.INSTALL,
                    success = true,
                    failure = null,
                    origin = BundleOrigin.DOWNLOAD,
                    fellBack = false,
                    bytes = zip.size,
                    durationMs = elapsed(started)
                ),
                fresh = true,
                fellBack = false
            )
            ready
        } catch (error: BundleException) {
            recover(cacheRoot, slot, key, fallback, error, zip.size, started)
        } catch (error: Exception) {
            val wrapped = BundleException(BundleFailure.IO, "模版没有写入本地", error)
            recover(cacheRoot, slot, key, fallback, wrapped, zip.size, started)
        }
    }

    fun load(
        cacheRoot: File,
        slot: String,
        publicKey: ByteArray,
        fallback: BundleFallback = BundleFallback.LAST_VERIFIED,
        fetcher: () -> BundleDownload
    ): InstalledBundle {
        val key = publicKey.copyOf()
        BundleStore.checkSlot(slot)
        requireKey(key)
        val fetchStarted = System.nanoTime()
        val downloaded = try {
            fetcher()
        } catch (error: BundleException) {
            emit(
                record(
                    slot = slot,
                    id = null,
                    stage = BundleStage.FETCH,
                    success = false,
                    failure = error.failure,
                    origin = null,
                    fellBack = false,
                    bytes = 0,
                    durationMs = elapsed(fetchStarted)
                ),
                countInstall = false,
                fresh = false,
                fellBack = false
            )
            return recover(cacheRoot, slot, key, fallback, error, 0, System.nanoTime())
        } catch (error: Exception) {
            val wrapped = BundleException(BundleFailure.NETWORK, error.message ?: "请求失败", error)
            emit(
                record(
                    slot = slot,
                    id = null,
                    stage = BundleStage.FETCH,
                    success = false,
                    failure = BundleFailure.NETWORK,
                    origin = null,
                    fellBack = false,
                    bytes = 0,
                    durationMs = elapsed(fetchStarted)
                ),
                countInstall = false,
                fresh = false,
                fellBack = false
            )
            return recover(cacheRoot, slot, key, fallback, wrapped, 0, System.nanoTime())
        }
        emit(
            record(
                slot = slot,
                id = downloaded.id,
                stage = BundleStage.FETCH,
                success = true,
                failure = null,
                origin = null,
                fellBack = false,
                bytes = downloaded.zip.size,
                durationMs = elapsed(fetchStarted)
            ),
            countInstall = false,
            fresh = false,
            fellBack = false
        )
        val started = System.nanoTime()
        return try {
            val opened = BundlePackage.open(downloaded.zip, key)
            if (opened.id != downloaded.id) {
                throw BundleException(BundleFailure.MANIFEST, "manifest 无效")
            }
            if (downloaded.intent != null && downloaded.intent != opened.intent) {
                throw BundleException(BundleFailure.MANIFEST, "manifest 无效")
            }
            if (downloaded.sample != null && downloaded.sample != opened.sample) {
                throw BundleException(BundleFailure.MANIFEST, "manifest 无效")
            }
            val root = BundleStore.commit(cacheRoot, slot, opened)
            val ready = installed(opened, root, BundleOrigin.DOWNLOAD, fellBack = false, failure = null)
            emit(
                record(
                    slot = slot,
                    id = ready.id,
                    stage = BundleStage.INSTALL,
                    success = true,
                    failure = null,
                    origin = BundleOrigin.DOWNLOAD,
                    fellBack = false,
                    bytes = downloaded.zip.size,
                    durationMs = elapsed(started)
                ),
                fresh = true,
                fellBack = false
            )
            ready
        } catch (error: BundleException) {
            recover(cacheRoot, slot, key, fallback, error, downloaded.zip.size, started)
        } catch (error: Exception) {
            val wrapped = BundleException(BundleFailure.IO, "模版没有写入本地", error)
            recover(cacheRoot, slot, key, fallback, wrapped, downloaded.zip.size, started)
        }
    }

    private fun recover(
        cacheRoot: File,
        slot: String,
        publicKey: ByteArray,
        fallback: BundleFallback,
        error: BundleException,
        bytes: Int,
        started: Long
    ): InstalledBundle {
        if (fallback == BundleFallback.LAST_VERIFIED) {
            val cached = BundleStore.read(cacheRoot, slot, publicKey)
            if (cached != null) {
                val ready = installed(
                    cached.opened,
                    cached.root,
                    BundleOrigin.CACHE,
                    fellBack = true,
                    failure = error.failure
                )
                emit(
                    record(
                        slot = slot,
                        id = ready.id,
                        stage = BundleStage.INSTALL,
                        success = true,
                        failure = error.failure,
                        origin = BundleOrigin.CACHE,
                        fellBack = true,
                        bytes = bytes,
                        durationMs = elapsed(started)
                    ),
                    fresh = false,
                    fellBack = true
                )
                return ready
            }
        }
        emit(
            record(
                slot = slot,
                id = null,
                stage = BundleStage.INSTALL,
                success = false,
                failure = error.failure,
                origin = null,
                fellBack = false,
                bytes = bytes,
                durationMs = elapsed(started)
            ),
            fresh = false,
            fellBack = false
        )
        throw error
    }

    private fun installed(
        opened: OpenedBundle,
        root: File,
        origin: BundleOrigin,
        fellBack: Boolean,
        failure: BundleFailure?
    ): InstalledBundle {
        return InstalledBundle(
            id = opened.id,
            root = root,
            origin = origin,
            intent = opened.intent,
            sample = opened.sample,
            fellBack = fellBack,
            failure = failure
        )
    }

    private fun requireKey(publicKey: ByteArray) {
        if (publicKey.size != 32) {
            throw BundleException(BundleFailure.PUBLIC_KEY, "公钥无效")
        }
    }

    private fun record(
        slot: String,
        id: String?,
        stage: BundleStage,
        success: Boolean,
        failure: BundleFailure?,
        origin: BundleOrigin?,
        fellBack: Boolean,
        bytes: Int,
        durationMs: Long
    ): BundleRecord {
        return BundleRecord(
            slot = slot,
            id = id,
            stage = stage,
            success = success,
            failure = failure,
            origin = origin,
            fellBack = fellBack,
            bytes = bytes,
            durationMs = durationMs,
            atMs = System.currentTimeMillis()
        )
    }

    private fun emit(
        record: BundleRecord,
        countInstall: Boolean = true,
        fresh: Boolean,
        fellBack: Boolean
    ) {
        if (record.stage == BundleStage.FETCH) {
            stats.fetch(record.success)
        }
        if (countInstall && record.stage == BundleStage.INSTALL) {
            stats.install(record.success, fresh, fellBack, record.failure)
        }
        for (listener in listeners) {
            try {
                listener.onRecord(record)
            } catch (_: Exception) {
            }
        }
    }

    private fun elapsed(started: Long): Long {
        return (System.nanoTime() - started) / 1_000_000
    }

    private class Stats {
        private val gate = Any()
        private var fetchAttempts = 0
        private var fetchSuccess = 0
        private var installAttempts = 0
        private var installSuccess = 0
        private var freshInstalls = 0
        private var cacheFallbacks = 0
        private val failures = linkedMapOf<BundleFailure, Int>()

        fun fetch(success: Boolean) {
            synchronized(gate) {
                fetchAttempts += 1
                if (success) {
                    fetchSuccess += 1
                }
            }
        }

        fun install(success: Boolean, fresh: Boolean, fellBack: Boolean, failure: BundleFailure?) {
            synchronized(gate) {
                installAttempts += 1
                if (success) {
                    installSuccess += 1
                }
                if (fresh && success) {
                    freshInstalls += 1
                }
                if (fellBack) {
                    cacheFallbacks += 1
                }
                if (failure != null) {
                    failures[failure] = (failures[failure] ?: 0) + 1
                }
            }
        }

        fun copy(): BundleSnapshot {
            synchronized(gate) {
                return BundleSnapshot(
                    fetchAttempts = fetchAttempts,
                    fetchSuccess = fetchSuccess,
                    installAttempts = installAttempts,
                    installSuccess = installSuccess,
                    freshInstalls = freshInstalls,
                    cacheFallbacks = cacheFallbacks,
                    failures = failures.toMap()
                )
            }
        }

        fun clear() {
            synchronized(gate) {
                fetchAttempts = 0
                fetchSuccess = 0
                installAttempts = 0
                installSuccess = 0
                freshInstalls = 0
                cacheFallbacks = 0
                failures.clear()
            }
        }
    }
}
