package com.dynamic.otter.render.utils

import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.expression.ExpressionWrapper
import com.dynamic.otter.render.node.DataBinding

object FunctionExt {
    fun String.extractExpValue(): String {
        return ExpressionWrapper.instance.getResult(this, DataBinding.instance.getData()).toString()
    }

    fun String.extractExpValue(data:JSONObject): String {
        return ExpressionWrapper.instance.getResult(this, data).toString()
    }

    fun String.isExp():Boolean = this.startsWith("$")

}