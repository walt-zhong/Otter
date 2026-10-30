package com.dynamic.otter.utils

import android.util.Log
import com.alibaba.fastjson.JSON
import com.alibaba.fastjson.JSONObject

fun String.toJson(): JSONObject = try {
    JSONObject.parseObject(this)
} catch (_: Exception) {
    JSONObject()
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
