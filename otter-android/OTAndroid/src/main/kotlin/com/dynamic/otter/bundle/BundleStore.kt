package com.dynamic.otter.bundle

import com.alibaba.fastjson.JSON
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.utils.AssetsUtils
import java.io.File
import java.util.concurrent.ConcurrentHashMap

internal data class CachedBundle(val opened: OpenedBundle, val root: File)

internal object BundleStore {
    private val locks = ConcurrentHashMap<String, Any>()
    private val slotPattern = Regex("[A-Za-z0-9][A-Za-z0-9._-]{0,63}")

    fun checkSlot(slot: String) {
        if (!slotPattern.matches(slot)) {
            throw BundleException(BundleFailure.PATH, "路径越界")
        }
    }

    fun commit(cacheRoot: File, slot: String, opened: OpenedBundle): File {
        checkSlot(slot)
        synchronized(lock(slot)) {
            val slotDir = slotDir(cacheRoot, slot)
            slotDir.mkdirs()
            recover(slotDir)
            val incoming = File(slotDir, "${opened.id}.incoming")
            incoming.deleteRecursively()
            try {
                writeTree(incoming, opened.files)
                val dest = File(slotDir, opened.id)
                val bak = File(slotDir, "${opened.id}.bak")
                if (bak.exists()) {
                    bak.deleteRecursively()
                }
                if (dest.exists() && !dest.renameTo(bak)) {
                    throw BundleException(BundleFailure.IO, "模版没有写入本地")
                }
                if (!incoming.renameTo(dest)) {
                    if (bak.exists()) {
                        bak.renameTo(dest)
                    }
                    throw BundleException(BundleFailure.IO, "模版没有写入本地")
                }
                try {
                    writePointer(slotDir, opened.id)
                } catch (error: Exception) {
                    dest.deleteRecursively()
                    if (bak.exists()) {
                        bak.renameTo(dest)
                    }
                    if (error is BundleException) {
                        throw error
                    }
                    throw BundleException(BundleFailure.IO, "模版没有写入本地", error)
                }
                if (bak.exists()) {
                    bak.deleteRecursively()
                }
                deleteOthers(slotDir, opened.id)
                return dest
            } catch (error: BundleException) {
                incoming.deleteRecursively()
                throw error
            } catch (error: Exception) {
                incoming.deleteRecursively()
                throw BundleException(BundleFailure.IO, "模版没有写入本地", error)
            }
        }
    }

    fun read(cacheRoot: File, slot: String, publicKey: ByteArray): CachedBundle? {
        checkSlot(slot)
        synchronized(lock(slot)) {
            val slotDir = slotDir(cacheRoot, slot)
            if (!slotDir.isDirectory) {
                return null
            }
            recover(slotDir)
            val id = readPointer(slotDir) ?: return null
            val dir = File(slotDir, id)
            try {
                val files = readTree(dir)
                val opened = BundlePackage.accept(files, publicKey)
                if (opened.id != id) {
                    throw BundleException(BundleFailure.MANIFEST, "manifest 无效")
                }
                return CachedBundle(opened, dir)
            } catch (error: BundleException) {
                if (error.failure != BundleFailure.SIGNATURE) {
                    dir.deleteRecursively()
                    File(slotDir, "current.json").delete()
                }
                return null
            } catch (error: Exception) {
                dir.deleteRecursively()
                File(slotDir, "current.json").delete()
                return null
            }
        }
    }

    private fun lock(slot: String): Any {
        return locks.computeIfAbsent(slot) { Any() }
    }

    private fun slotDir(cacheRoot: File, slot: String): File {
        return File(cacheRoot, "otter-bundles/$slot")
    }

    private fun writeTree(dir: File, files: Map<String, ByteArray>) {
        dir.mkdirs()
        for ((name, body) in files) {
            val safe = AssetsUtils.containedAssetPath(name)
                ?: throw BundleException(BundleFailure.PATH, "路径越界")
            val out = File(dir, safe)
            val base = dir.canonicalFile
            val parent = out.parentFile ?: throw BundleException(BundleFailure.IO, "模版没有写入本地")
            parent.mkdirs()
            val target = out.canonicalFile
            val prefix = base.path + File.separator
            if (target.path != base.path && !target.path.startsWith(prefix)) {
                throw BundleException(BundleFailure.PATH, "路径越界")
            }
            out.writeBytes(body)
        }
    }

    private fun readTree(dir: File): Map<String, ByteArray> {
        val names = listOf(
            "routes.json",
            "templates/list.json",
            "templates/detail.json",
            "data/list.json",
            "data/detail.json",
            "manifest.json"
        )
        val base = dir.canonicalFile
        val files = linkedMapOf<String, ByteArray>()
        for (name in names) {
            val safe = AssetsUtils.containedAssetPath(name)
                ?: throw BundleException(BundleFailure.PATH, "路径越界")
            val file = File(base, safe).canonicalFile
            val prefix = base.path + File.separator
            if (file.path != base.path && !file.path.startsWith(prefix)) {
                throw BundleException(BundleFailure.PATH, "路径越界")
            }
            if (!file.isFile) {
                throw BundleException(BundleFailure.IO, "模版没有写入本地")
            }
            files[name] = file.readBytes()
        }
        return files
    }

    private fun writePointer(slotDir: File, id: String) {
        val pointer = JSONObject()
        pointer["id"] = id
        val tmp = File(slotDir, "current.json.tmp")
        tmp.writeText(pointer.toJSONString(), Charsets.UTF_8)
        val dest = File(slotDir, "current.json")
        if (dest.exists() && !dest.delete()) {
            throw BundleException(BundleFailure.IO, "模版没有写入本地")
        }
        if (!tmp.renameTo(dest)) {
            throw BundleException(BundleFailure.IO, "模版没有写入本地")
        }
    }

    private fun readPointer(slotDir: File): String? {
        val pointer = File(slotDir, "current.json")
        if (!pointer.isFile) {
            return null
        }
        val parsed = try {
            JSON.parseObject(pointer.readText(Charsets.UTF_8))
        } catch (error: Exception) {
            return null
        } ?: return null
        val id = parsed.getString("id")
        if (id.isNullOrEmpty()) {
            return null
        }
        return id
    }

    private fun recover(slotDir: File) {
        val children = slotDir.listFiles() ?: return
        for (child in children) {
            if (!child.isDirectory) {
                continue
            }
            when {
                child.name.endsWith(".incoming") -> child.deleteRecursively()
                child.name.endsWith(".bak") -> {
                    val dest = File(slotDir, child.name.removeSuffix(".bak"))
                    if (!dest.exists()) {
                        child.renameTo(dest)
                    } else {
                        child.deleteRecursively()
                    }
                }
            }
        }
    }

    private fun deleteOthers(slotDir: File, id: String) {
        val children = slotDir.listFiles() ?: return
        for (child in children) {
            if (child.isDirectory && child.name != id) {
                child.deleteRecursively()
            }
        }
    }
}
