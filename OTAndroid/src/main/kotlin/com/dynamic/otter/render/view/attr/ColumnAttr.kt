package com.dynamic.otter.render.view.attr

import com.dynamic.otter.template.OTFlexBox

class ColumnAttr : ContainerAttr() {
    override fun parseAttrs(attrs: Map<String, String>): ViewAttr {
        val columnAttr = super.parseAttrs(attrs) as ColumnAttr
        flexbox = OTFlexBox.create(columnAttr)
        return columnAttr
    }

    override fun toString(): String {
        return "ColumnAttr(id = $id, width=$width, height = $height ,radius='$radius',flexbox='$flexbox')"
    }

    companion object {
        fun create(attrs: Map<String, String>): ViewAttr {
            return ColumnAttr().parseAttrs(attrs)
        }
    }
}
