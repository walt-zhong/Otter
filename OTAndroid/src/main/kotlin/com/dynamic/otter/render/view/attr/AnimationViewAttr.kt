package com.dynamic.otter.render.view.attr

import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue

class AnimationViewAttr : ViewAttr() {
    var animationSrc: String? = null
    var repeatCount: String? = null
    var repeatMode: String? = null
    var autoPlay: String? = null

    override fun applyOwn(name: String, raw: String, scope: TemplateContext) {
        val value = raw.extractExpValue(scope.data)
        when (name) {
            TemplateKey.ATTR_ANIMATION_SRC -> animationSrc = value
            TemplateKey.ATTR_ANI_REPEAT_COUNT -> repeatCount = value
            TemplateKey.ATTR_ANI_REPEAT_MODE -> repeatMode = value
            TemplateKey.ATTR_ANI_AUTO_PLAY -> autoPlay = value
        }
    }

    companion object {
        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            return AnimationViewAttr().bind(attrs, scope)
        }
    }
}
