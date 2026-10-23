package com.dynamic.otter.render.view.attr

import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.template.OTFlexBox

class SpacerAttr : ViewAttr() {
    override fun parseAttrs(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
        val spacerAttr = super.parseAttrs(attrs, scope)
        flexbox = OTFlexBox.create(spacerAttr)
        return spacerAttr
    }

    companion object {
        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            return SpacerAttr().parseAttrs(attrs, scope)
        }
    }
}
