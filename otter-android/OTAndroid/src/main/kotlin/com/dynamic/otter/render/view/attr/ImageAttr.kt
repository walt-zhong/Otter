package com.dynamic.otter.render.view.attr

import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue

class ImageAttr : ViewAttr() {
    var src = ""
    var fit = "cover"
    var placeholder: String? = null

    override fun applyOwn(name: String, raw: String, scope: TemplateContext) {
        val value = raw.extractExpValue(scope.data)
        when (name) {
            TemplateKey.ATTR_SRC -> src = value
            "fit" -> fit = value.ifBlank { "cover" }
            "placeholder" -> placeholder = value.ifBlank { null }
        }
    }

    companion object {
        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            return ImageAttr().bind(attrs, scope)
        }
    }
}
