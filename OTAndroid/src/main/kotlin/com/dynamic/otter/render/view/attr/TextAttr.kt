package com.dynamic.otter.render.view.attr

import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue

class TextAttr : ViewAttr() {
    var textColor = "#000000"
    var textSize = "12px"
    var text = ""
    var textAlign: String? = null

    override fun applyOwn(name: String, raw: String, scope: TemplateContext) {
        val value = raw.extractExpValue(scope.data)
        when (name) {
            TemplateKey.ATTR_TEXT_COLOR -> textColor = value
            TemplateKey.ATTR_TEXT_SIZE -> textSize = value
            TemplateKey.ATTR_TEXT -> text = value
            TemplateKey.ATTR_TEXT_ALIGN -> textAlign = value
        }
    }

    companion object {
        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            return TextAttr().bind(attrs, scope)
        }
    }
}
