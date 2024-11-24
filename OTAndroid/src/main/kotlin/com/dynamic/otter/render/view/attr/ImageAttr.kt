package com.dynamic.otter.render.view.attr

import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.template.OTFlexBox
import org.w3c.dom.NamedNodeMap

class ImageAttr : ViewAttr() {
    var src = ""
    var placeholder = ""

    override fun parseAttrs(attrsMap: NamedNodeMap): ViewAttr {
        for (i in 0 until attrsMap.length) {
            val attrName = attrsMap.item(i).nodeName
            val attrValue = attrsMap.item(i).nodeValue
            when (attrName) {
                TemplateKey.ATTR_SRC -> {
                    src = attrValue.extractExpValue()
                }

                TemplateKey.ATTR_PLACEHOLDER -> {
                    placeholder = attrValue.extractExpValue()
                }
            }
        }

        val sdImgAttr = super.parseAttrs(attrsMap) as ImageAttr
        flexbox = OTFlexBox.create(sdImgAttr)
        return sdImgAttr
    }

    override fun toString(): String {
        return "ImageAttr(id = $id, width=${width}, height = ${height} ,src='$src',flexbox='$flexbox')"
    }

    companion object {
        fun create(attrMap: NamedNodeMap): ViewAttr {
            return ImageAttr().parseAttrs(attrMap)
        }
    }
}