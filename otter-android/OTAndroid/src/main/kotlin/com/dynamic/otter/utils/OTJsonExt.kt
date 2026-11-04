package com.dynamic.otter.utils

import android.util.Log
import com.alibaba.fastjson.JSON
import com.alibaba.fastjson.JSONObject
import com.alibaba.fastjson.parser.ParserConfig

private object FastjsonGuard {
    init {
        ParserConfig.getGlobalInstance().isSafeMode = true
    }
}

fun String.toJson(): JSONObject {
    FastjsonGuard
    if (isBlank()) {
        return JSONObject()
    }
    return try {
        JSON.parseObject(this) ?: throw IllegalArgumentException("JSON 必须是对象")
    } catch (error: Exception) {
        Log.e("Otter", "rejected invalid JSON", error)
        throw error
    }
}

fun JSON.getAnyExt(valuePath: String): Any? {
    return try {
        val keyIndex = valuePath.indexOf(".")
        val arrayLeftSymbolIndex = valuePath.indexOf("[")
        val arrayRightSymbolIndex = valuePath.indexOf("]")

        if (keyIndex == -1 && arrayLeftSymbolIndex != -1 && arrayRightSymbolIndex != -1) {
            val arrayName = valuePath.substring(0, arrayLeftSymbolIndex)
            val arrayIndex = valuePath.substring(arrayLeftSymbolIndex + 1, arrayRightSymbolIndex).toInt()
            val array = (this as? JSONObject)?.getJSONArray(arrayName) ?: return null
            if (arrayIndex !in array.indices) {
                Log.e(
                    "Otter",
                    "getAnyExt IndexOutOfBounds: XPath: $valuePath Index: $arrayIndex, Size: ${array.size}"
                )
                return null
            }
            return array[arrayIndex]
        }

        if (keyIndex == -1 && arrayLeftSymbolIndex == -1 && arrayRightSymbolIndex == -1) {
            return (this as? JSONObject)?.get(valuePath)
        }

        val firstKey = valuePath.substring(0, keyIndex).trim()
        val restKey = valuePath.substring(keyIndex + 1, valuePath.length)
        ((this as? JSONObject)?.getAnyExt(firstKey) as? JSON)?.getAnyExt(restKey)
    } catch (error: Exception) {
        error.printStackTrace()
        null
    }
}
