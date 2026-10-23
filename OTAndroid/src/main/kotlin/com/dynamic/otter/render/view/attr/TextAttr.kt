package com.dynamic.otter.render.view.attr

import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.template.OTFlexBox

class TextAttr : ViewAttr() {
    var textColor = "#000000"
    var textSize = "12px"
    var text = ""
    var textAlign: String? = null

    override fun parseAttrs(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
        val textAttr = super.parseAttrs(attrs, scope) as TextAttr
        attrs.forEach { (attrName, rawValue) ->
            val attrValue = rawValue.extractExpValue(scope.data)
            when (attrName) {
                TemplateKey.ATTR_TEXT_COLOR -> textColor = attrValue
                TemplateKey.ATTR_TEXT_SIZE -> textSize = attrValue
                TemplateKey.ATTR_TEXT -> text = attrValue
                TemplateKey.ATTR_TEXT_ALIGN -> textAlign = attrValue
            }
        }
        flexbox = OTFlexBox.create(textAttr)
        return textAttr
    }

    companion object {
        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            return TextAttr().parseAttrs(attrs, scope)
        }
    }
}
