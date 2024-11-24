package com.dynamic.otter.render.view.attr

import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.template.OTFlexBox
import org.w3c.dom.NamedNodeMap

class ProgressAttr : ViewAttr() {
    var trailColor = "red" // 进度条的轨迹颜色，即进度条的颜色，默认为红色
    var strokeColor = "gray" // 进度条的描边颜色，即进度条的背景色，默认为灰色
    var animateEnable = false // 是否需要动画，默认不需要
    var valueMin = "0" // 进度的最小值，默认为0
    var valueMax = "1" // 进度最大值，默认为1


    override fun parseAttrs(attrsMap: NamedNodeMap): ViewAttr {
        val progressAttr = super.parseAttrs(attrsMap) as ProgressAttr
        for (i in 0 until attrsMap.length) {
            val attrName = attrsMap.item(i).nodeName
            val attrValue = attrsMap.item(i).nodeValue.extractExpValue()
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
        fun create(attrMap: NamedNodeMap): ViewAttr {
            return ProgressAttr().parseAttrs(attrMap)
        }
    }
}