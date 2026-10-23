package com.dynamic.otter.render.view.attr

import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.template.OTFlexBox

class AnimationViewAttr : ViewAttr() {
    var animationSrc: String? = null
    var repeatCount: String? = null
    var repeatMode: String? = null
    var autoPlay: String? = null

    override fun parseAttrs(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
        val animationAttr = super.parseAttrs(attrs, scope) as AnimationViewAttr
        attrs.forEach { (attrName, rawValue) ->
            val attrValue = rawValue.extractExpValue(scope.data)
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
        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            return AnimationViewAttr().parseAttrs(attrs, scope)
        }
    }
}
