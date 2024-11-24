package com.dynamic.otter.render.view.attr

import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.template.OTFlexBox
import org.w3c.dom.NamedNodeMap

class AnimationViewAttr : ViewAttr() {
    var animationSrc: String? = null
    var repeatCount: String? = null
    var repeatMode: String? = null
    var autoPlay: String? = null

    override fun parseAttrs(attrsMap: NamedNodeMap): ViewAttr {
        val animationAttr = super.parseAttrs(attrsMap) as AnimationViewAttr
        for (i in 0 until attrsMap.length) {
            val attrName = attrsMap.item(i).nodeName
            val attrValue = attrsMap.item(i).nodeValue.extractExpValue()
            when (attrName) {
                TemplateKey.ATTR_ANIMATION_SRC -> animationSrc = attrValue
                TemplateKey.ATTR_ANI_REPEAT_COUNT -> repeatCount = attrValue
                TemplateKey.ATTR_ANI_REPEAT_MODE -> repeatMode = attrValue
                TemplateKey.ATTR_ANI_AUTO_PLAY -> autoPlay = attrValue
            }
        }

        flexbox = OTFlexBox.create(animationAttr)
        return animationAttr
    }

    companion object {
        fun create(attrMap: NamedNodeMap): ViewAttr {
            return AnimationViewAttr().parseAttrs(attrMap)
        }
    }
}