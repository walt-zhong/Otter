package com.dynamic.otter.render.view.attr

import com.dynamic.otter.context.TemplateContext

class SpacerAttr : ViewAttr() {
    companion object {
        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            return SpacerAttr().bind(attrs, scope)
        }
    }
}
