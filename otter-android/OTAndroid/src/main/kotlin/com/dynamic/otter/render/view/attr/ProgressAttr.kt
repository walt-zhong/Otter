package com.dynamic.otter.render.view.attr

import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue

class ProgressAttr : ViewAttr() {
    var trailColor = "red"
    var strokeColor = "gray"
    var animateEnable = false
    var valueMin = "0"
    var valueMax = "1"

    override fun applyOwn(name: String, raw: String, scope: TemplateContext) {
        val value = raw.extractExpValue(scope.data)
        when (name) {
            TemplateKey.ATTR_TRAIL_COLOR -> trailColor = value
            TemplateKey.ATTR_STROKE_COLOR -> strokeColor = value
            TemplateKey.ATTR_ANIMATE_ENABLE -> animateEnable = value == "true"
            TemplateKey.ATTR_VALUE_MIN -> valueMin = value
            TemplateKey.ATTR_VALUE_MAX -> valueMax = value
        }
    }

    companion object {
        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            return ProgressAttr().bind(attrs, scope)
        }
    }
}
