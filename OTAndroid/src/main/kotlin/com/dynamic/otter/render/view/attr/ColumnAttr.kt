package com.dynamic.otter.render.view.attr

import com.dynamic.otter.template.OTFlexBox
import org.w3c.dom.NamedNodeMap

class ColumnAttr : ContainerAttr() {
    override fun parseAttrs(attrsMap: NamedNodeMap): ViewAttr {
        val columnAttr = super.parseAttrs(attrsMap) as ColumnAttr
        flexbox = OTFlexBox.create(columnAttr)
        return columnAttr
    }

    override fun toString(): String {
        return "ColumnAttr(id = $id, width=$width, height = $height ,radius='$radius',flexbox='$flexbox')"
    }

    companion object {
        fun create(attrMap: NamedNodeMap): ViewAttr {
            return ColumnAttr().parseAttrs(attrMap)
        }
    }
}
