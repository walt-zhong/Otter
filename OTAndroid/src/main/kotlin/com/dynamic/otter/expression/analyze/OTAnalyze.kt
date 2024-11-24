package com.dynamic.otter.expression.analyze

import androidx.annotation.Keep
import com.alibaba.fastjson.JSONArray
import com.alibaba.fastjson.JSONObject

@Keep
class OTAnalyze {
    // 计算逻辑的扩展
    @Keep
    interface IComputeExtend {

        // Computed value expression
        fun computeValueExpression(valuePath: String, source: Any?): Long

        // Computed function expression
        fun computeFunctionExpression(functionName: String, params: LongArray): Long
    }

    val pointer: Long = 0L

    var computeExtend: IComputeExtend? = null

    init {
        initNative(this)
    }

    fun initComputeExtend(computeExtend: IComputeExtend) {
        this.computeExtend = computeExtend
    }

    companion object {
        init {
            System.loadLibrary("OTAnalyze")
        }

        external fun getValueTag(value: Long): Int
        external fun getValueString(value: Long): String
        external fun getValueBoolean(value: Long): Boolean
        external fun getValueFloat(value: Long): Float
        external fun getValueArray(value: Long): Any?
        external fun getValueMap(value: Long): Any?
        external fun getValueLong(value: Long): Long
        external fun createValueFloat64(value: Float): Long
        external fun createValueString(value: String): Long
        external fun createValueBool(value: Boolean): Long
        external fun createValueArray(value: Any?): Long
        external fun createValueMap(value: Any?): Long
        external fun createValueNull(): Long
        external fun createValueLong(value: Long): Long
        external fun releaseOTValue(value: Long)

        val TYPE_FLOAT = 0
        val TYPE_BOOLEAN = 1
        val TYPE_NULL = 2
        val TYPE_VALUE = 3
        val TYPE_STRING = 4
        val TYPE_OBJECT = 5
        val TYPE_ARRAY = 6
        val TYPE_MAP = 7
        val TYPE_LONG = 8
        val TYPE_EXCEPTION = 9

        fun wrapAsSDValue(value: Long): OTValue? {
            try {
                check(value != 0L) { "Can't wrap null pointer as SDValue" }
                var gxValue: OTValue? = null
                val type: Int = getValueTag(value)
                when (type) {
                    TYPE_NULL -> gxValue = OTNull()
                    TYPE_STRING -> gxValue = OTString(getValueString(value))
                    TYPE_ARRAY -> gxValue = OTArray(getValueArray(value))
                    TYPE_MAP -> gxValue = OTMap(getValueMap(value))
                    TYPE_BOOLEAN -> gxValue = OTBool(getValueBoolean(value))
                    TYPE_FLOAT -> gxValue = OTFloat(getValueFloat(value))
                    TYPE_LONG -> gxValue = OTLong(getValueLong(value))
                }
                releaseOTValue(value)
                return gxValue
            } catch (_: Exception) {
            }
            return null
        }
    }

    fun getResult(expression: Any, data: Any?): Any? {
        when (expression) {
            is String -> {
                if (expression.trim() == "\$\$") {
                    return data
                } else if (expression.trim() == "") {
                    return null
                }
                val result = this.getResultNative(this, expression, data)
                return wrapAsSDValue(result)?.getValue()
            }
            is Int -> {
                return expression
            }
            is Long -> {
                return expression
            }
            is Float -> {
                return expression
            }
            is Boolean -> {
                return expression
            }
            is JSONObject -> {
                return getJsonResult(expression, data)
            }
            is JSONArray -> {
                return getJsonArrayResult(expression, data)
            }
            else -> return null
        }
    }

    private fun getJsonArrayResult(expression: JSONArray, data: Any?): Any? {
        return JSONArray().apply {
            expression.forEach {
                this.add(getResult(it, data))
            }
        }
    }

    private fun getJsonResult(expression: JSONObject, data: Any?): Any {
        return JSONObject().apply {
            expression.forEach {
                this[it.key] = getResult(it.value, data)
            }
        }
    }

    private external fun getResultNative(self: Any, expression: String, data: Any?): Long

    private external fun initNative(self: Any)
}