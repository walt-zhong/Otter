package com.dynamic.otter.utils

import android.content.Context

object AssetsUtils {
    fun parseAssetsToString(context: Context, path: String): String {
        return context.resources.assets.open(path).bufferedReader(Charsets.UTF_8).use { it.readText() }
    }
}
