package com.dynamic.otter.render.view.attr

import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue

class ImageAttr : ViewAttr() {
    var src = ""

    override fun applyOwn(name: String, raw: String, scope: TemplateContext) {
        if (name == TemplateKey.ATTR_SRC) {
            src = raw.extractExpValue(scope.data)
        }
    }

    companion object {
        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            return ImageAttr().bind(attrs, scope)
        }
    }
}
