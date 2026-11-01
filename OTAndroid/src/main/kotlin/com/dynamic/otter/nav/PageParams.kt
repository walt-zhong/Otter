package com.dynamic.otter.nav

import com.alibaba.fastjson.JSONArray
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.render.utils.FunctionExt.isExp
import java.math.BigDecimal

internal object PageParams {
    fun evaluate(raw: JSONObject, resolve: (String) -> Any?): JSONObject {
        return copyTree(raw, resolve) as JSONObject
    }

    fun matches(data: JSONObject?, overlay: JSONObject?): Boolean {
        if (overlay == null || overlay.isEmpty()) {
            return true
        }
        if (data == null) {
            return false
        }
        for (key in overlay.keys) {
            if (!sameValue(data.get(key), overlay.get(key))) {
                return false
            }
        }
        return true
    }

    fun mergeInto(target: JSONObject, overlay: JSONObject) {
        for (key in overlay.keys) {
            target[key] = overlay.get(key)
        }
    }

    fun findItem(page: JSONObject?, item: JSONObject?): Pair<String, Int>? {
        if (page == null || item == null) {
            return null
        }
        for (key in page.keys) {
            val array = page.get(key) as? JSONArray ?: continue
            for (index in 0 until array.size) {
                if (array[index] === item) {
                    return key to index
                }
            }
        }
        return null
    }

    fun merge(base: JSONObject?, overlay: JSONObject?): JSONObject? {
        if (base == null && overlay == null) {
            return null
        }
        val result = JSONObject()
        copy(result, base)
        copy(result, overlay)
        return result
    }

    private fun copy(target: JSONObject, source: JSONObject?) {
        if (source == null) {
            return
        }
        for (key in source.keys) {
            target[key] = source.get(key)
        }
    }

    private fun copyTree(value: Any?, resolve: (String) -> Any?): Any? {
        return when (value) {
            is JSONObject -> {
                val copy = JSONObject()
                for (key in value.keys) {
                    copy[key] = copyTree(value.get(key), resolve)
                }
                copy
            }
            is JSONArray -> {
                val copy = JSONArray()
                for (index in 0 until value.size) {
                    copy.add(copyTree(value.get(index), resolve))
                }
                copy
            }
            is String -> if (value.isExp()) resolve(value) ?: value else value
            else -> value
        }
    }

    private fun sameValue(left: Any?, right: Any?): Boolean {
        if (left == null || right == null) {
            return left == null && right == null
        }
        if (left is Boolean || right is Boolean) {
            return left == right
        }
        if (left is Number && right is Number) {
            return try {
                BigDecimal(left.toString()).compareTo(BigDecimal(right.toString())) == 0
            } catch (_: Exception) {
                left.toString() == right.toString()
            }
        }
        if (left is JSONObject && right is JSONObject) {
            if (left.size != right.size) {
                return false
            }
            return left.keys.all { key -> sameValue(left.get(key), right.get(key)) }
        }
        if (left is JSONArray && right is JSONArray) {
            if (left.size != right.size) {
                return false
            }
            return (0 until left.size).all { index -> sameValue(left.get(index), right.get(index)) }
        }
        return left == right
    }
}
