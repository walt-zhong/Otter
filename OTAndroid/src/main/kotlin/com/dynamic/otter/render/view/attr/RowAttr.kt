package com.dynamic.otter.render.view.attr

import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.template.OTFlexBox
import org.w3c.dom.NamedNodeMap

class RowAttr : ContainerAttr() {
    override fun parseAttrs(attrsMap: NamedNodeMap): ViewAttr {
        for (i in 0 until attrsMap.length) {
            val attrName = attrsMap.item(i).nodeName
            val attrValue = attrsMap.item(i).nodeValue
            when (attrName) {
                TemplateKey.ATTR_RADIUS -> {
                    radius = attrValue
                }
            }
        }
        val sdRowAttr = super.parseAttrs(attrsMap) as RowAttr
        flexbox = OTFlexBox.create(sdRowAttr)
        return sdRowAttr
    }

    override fun toString(): String {
        return "RowAttr(id = $id, width=${width}, height = ${height} ,radius='$radius',flexbox='$flexbox')"
    }

    companion object {
        fun create(attrMap: NamedNodeMap): ViewAttr {
            return RowAttr().parseAttrs(attrMap)
        }
    }
}