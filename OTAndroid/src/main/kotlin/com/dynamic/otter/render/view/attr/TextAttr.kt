package com.dynamic.otter.render.view.attr

import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.template.OTFlexBox

class TextAttr : ViewAttr() {
    var textColor = "#000000"
    var textSize = "12px"
    var text = ""
    var textAlign: String? = null
    var includeFontPadding = "false"

    override fun parseAttrs(attrs: Map<String, String>): ViewAttr {
        attrs.forEach { (attrName, rawValue) ->
            val attrValue = rawValue.extractExpValue()
            when (attrName) {
                TemplateKey.ATTR_TEXT_COLOR -> textColor = attrValue
                TemplateKey.ATTR_TEXT_SIZE -> textSize = attrValue
                TemplateKey.ATTR_TEXT -> text = attrValue
                TemplateKey.ATTR_TEXT_ALIGN -> textAlign = attrValue
                TemplateKey.ATTR_INCLUDE_FONT_PADDING -> includeFontPadding = attrValue
            }
        }
        val textAttr = super.parseAttrs(attrs) as TextAttr
        flexbox = OTFlexBox.create(textAttr)
        return textAttr
    }

    override fun toString(): String {
        return "TextAttr(id = $id, width=$width, height = $height ,textColor='$textColor',flexbox='$flexbox')"
    }

    companion object {
        fun create(attrs: Map<String, String>): ViewAttr {
            return TextAttr().parseAttrs(attrs)
        }
    }
}
