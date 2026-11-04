package com.dynamic.otter.utils

import android.content.Context
import java.io.File

object AssetsUtils {
    fun parseAssetsToString(context: Context, path: String): String {
        val safe = containedAssetPath(path)
            ?: throw IllegalArgumentException("资源路径越界")
        return context.resources.assets.open(safe).bufferedReader(Charsets.UTF_8).use { it.readText() }
    }

    fun readRelative(root: File, path: String): String {
        val safe = containedAssetPath(path)
            ?: throw IllegalArgumentException("资源路径越界")
        val base = root.canonicalFile
        val file = File(base, safe).canonicalFile
        val prefix = base.path + File.separator
        if (file.path != base.path && !file.path.startsWith(prefix)) {
            throw IllegalArgumentException("资源路径越界")
        }
        if (!file.isFile) {
            throw IllegalArgumentException("资源不存在")
        }
        return file.readText(Charsets.UTF_8)
    }

    /** Rejects absolute paths and `..` so a template path cannot leave the asset root. */
    fun containedAssetPath(path: String): String? {
        if (path.isEmpty() || path[0] == '/' || path[0] == '\\' || path.indexOf('\u0000') >= 0) {
            return null
        }
        if (path.contains('\\')) {
            return null
        }
        val parts = path.split('/')
        if (parts.any { it == ".." || it == "." }) {
            return null
        }
        return path
    }
}
