package com.dynamic.otter.render.view.attr

import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.template.OTFlexBox

class ProgressAttr : ViewAttr() {
    var trailColor = "red"
    var strokeColor = "gray"
    var animateEnable = false
    var valueMin = "0"
    var valueMax = "1"

    override fun parseAttrs(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
        val progressAttr = super.parseAttrs(attrs, scope) as ProgressAttr
        attrs.forEach { (attrName, rawValue) ->
            val attrValue = rawValue.extractExpValue(scope.data)
            when (attrName) {
                TemplateKey.ATTR_TRAIL_COLOR -> trailColor = attrValue
                TemplateKey.ATTR_STROKE_COLOR -> strokeColor = attrValue
                TemplateKey.ATTR_ANIMATE_ENABLE -> animateEnable = attrValue == "true"
                TemplateKey.ATTR_VALUE_MIN -> valueMin = attrValue
                TemplateKey.ATTR_VALUE_MAX -> valueMax = attrValue
            }
        }
        flexbox = OTFlexBox.create(progressAttr)
        return progressAttr
    }

    companion object {
        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            return ProgressAttr().parseAttrs(attrs, scope)
        }
    }
}
