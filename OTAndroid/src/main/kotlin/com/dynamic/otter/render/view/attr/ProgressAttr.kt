package com.dynamic.otter.render.view.attr

import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.template.OTFlexBox

class ProgressAttr : ViewAttr() {
    var trailColor = "red" // 进度颜色
    var strokeColor = "gray" // 轨道颜色
    var animateEnable = false
    var valueMin = "0"
    var valueMax = "1"

    override fun parseAttrs(attrs: Map<String, String>): ViewAttr {
        val progressAttr = super.parseAttrs(attrs) as ProgressAttr
        attrs.forEach { (attrName, rawValue) ->
            val attrValue = rawValue.extractExpValue()
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
        fun create(attrs: Map<String, String>): ViewAttr {
            return ProgressAttr().parseAttrs(attrs)
        }
    }
}
