package com.dynamic.otter.expression

import com.alibaba.fastjson.JSONArray
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.expression.analyze.OTAnalyze
import com.dynamic.otter.expression.analyze.OTArray
import com.dynamic.otter.expression.analyze.OTMap
import com.dynamic.otter.expression.analyze.OTString
import com.dynamic.otter.utils.getAnyExt
import java.math.BigDecimal

class ExpressionWrapper {
    private val analyze = OTAnalyze()

    init {
        analyze.initComputeExtend(object : OTAnalyze.IComputeExtend {

            /**
             * 用于处理取值逻辑
             */
            override fun computeValueExpression(valuePath: String, source: Any?): Long {
                if (valuePath == "$$") {
                    if (source is JSONArray) {
                        return OTAnalyze.createValueArray(source)
                    } else if (source is JSONObject) {
                        return OTAnalyze.createValueMap(source)
                    }
                }
                if (source is JSONObject) {
                    when (val value = source.getAnyExt(valuePath)) {
                        is JSONArray -> {
                            return OTAnalyze.createValueArray(value)
                        }

                        is JSONObject -> {
                            return OTAnalyze.createValueMap(value)
                        }

                        is Boolean -> {
                            return OTAnalyze.createValueBool(value)
                        }

                        is String -> {
                            return OTAnalyze.createValueString(value)
                        }

                        is Int -> {
                            return OTAnalyze.createValueLong(value.toLong())
                        }

                        is Float -> {
                            return OTAnalyze.createValueFloat64(value)
                        }

                        is Double -> {
                            return OTAnalyze.createValueFloat64(value.toFloat())
                        }

                        is BigDecimal -> {
                            return OTAnalyze.createValueFloat64(value.toFloat())
                        }

                        is Long -> {
                            return OTAnalyze.createValueLong(value)
                        }

                        null -> {
                            return OTAnalyze.createValueNull()
                        }

                        else -> {
                            throw IllegalArgumentException("Not recognize value = $value")
                        }
                    }
                }
                return 0L
            }

            /**
             * 用于处理函数逻辑
             */
            override fun computeFunctionExpression(
                functionName: String, params: LongArray
            ): Long {
                if (functionName == "size" && params.size == 1) {
                    return functionSize(params)
                } else if (functionName == "env" && params.size == 1) {
                    return functionEnv(params)
                }
                return 0L
            }
        })
    }

    private fun functionEnv(params: LongArray): Long {
        val value = OTAnalyze.wrapAsSDValue(params[0])
        if (value is OTString) {
            val envValue = value.getString()
            if ("isAndroid".equals(envValue, ignoreCase = true)) {
                return OTAnalyze.createValueBool(true)
            } else if ("isiOS".equals(envValue, ignoreCase = true)) {
                return OTAnalyze.createValueBool(false)
            }
        }
        return 0L
    }

    private fun functionSize(params: LongArray): Long {
        when (val value = OTAnalyze.wrapAsSDValue(params[0])) {
            is OTString -> {
                value.getString()?.let {
                    return OTAnalyze.createValueFloat64(it.length.toFloat())
                }
            }

            is OTMap -> {
                (value.getValue() as? JSONObject)?.let {
                    return OTAnalyze.createValueFloat64(it.size.toFloat())
                }
            }

            is OTArray -> {
                (value.getValue() as? JSONArray)?.let {
                    return OTAnalyze.createValueFloat64(it.size.toFloat())
                }
            }

            else -> {
                return OTAnalyze.createValueFloat64(0f)
            }
        }
        // nothing
        return 0L
    }

    fun getResult(expression: Any, data: Any?): Any? {
        var result = analyze.getResult(expression, data)
        // 如果表达式是String类型的，这时候的可能是表达式也可能不是，如果通过
        // 表达式引擎计算失败（不是表达式或者是表达式错误比如"${xxx"这种少了右大括号的）
        // 这时我们将表达式作为结果返回就行
        if (expression is String && result == null) {
            result = expression
        }
        return result
    }


    companion object {
        val instance by lazy {
            ExpressionWrapper()
        }
    }
}