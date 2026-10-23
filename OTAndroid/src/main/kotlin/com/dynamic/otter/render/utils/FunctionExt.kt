package com.dynamic.otter.render.utils

import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.expression.ExpressionWrapper

object FunctionExt {
    fun String.extractExpValue(data: JSONObject? = null): String {
        return ExpressionWrapper.instance.getResult(this, data).toString()
    }

    fun String.isExp(): Boolean = this.startsWith("$")
}
