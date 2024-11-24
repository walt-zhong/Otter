package com.dynamic.otter.render.view.attr

import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.template.OTFlexBox
import org.w3c.dom.NamedNodeMap

class TextAttr : ViewAttr() {
    var textColor = "#000000"
    var textSize = "12px"
    var text = ""
    var textAlign:String? = null
    var includeFontPadding = "false"

    override fun parseAttrs(attrsMap: NamedNodeMap): ViewAttr {
        for (i in 0 until attrsMap.length) {
            val attrName = attrsMap.item(i).nodeName
            val attrValue = attrsMap.item(i).nodeValue.extractExpValue()
            when (attrName) {
                TemplateKey.ATTR_TEXT_COLOR -> {
                    textColor = attrValue
                }

                TemplateKey.ATTR_TEXT_SIZE -> {
                    textSize = attrValue
                }

                TemplateKey.ATTR_TEXT -> {
                    text = attrValue
                }

                TemplateKey.ATTR_TEXT_ALIGN -> {
                    textAlign = attrValue
                }

                TemplateKey.ATTR_INCLUDE_FONT_PADDING->{
                    includeFontPadding = attrValue
                }
            }
        }

        val sdTextAttr = super.parseAttrs(attrsMap) as TextAttr
        flexbox = OTFlexBox.create(sdTextAttr)

        return super.parseAttrs(attrsMap)
    }

    override fun toString(): String {
        return "TextAttr(id = $id, width=${width}, height = $height ,textColor='$textColor',flexbox='$flexbox')"
    }

    companion object {
        fun create(attrMap: NamedNodeMap): ViewAttr {
            return TextAttr().parseAttrs(attrMap)
        }
    }
}