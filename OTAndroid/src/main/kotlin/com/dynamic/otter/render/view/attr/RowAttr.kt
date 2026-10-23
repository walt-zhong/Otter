package com.dynamic.otter.render.view.attr

import com.dynamic.otter.template.OTFlexBox

class RowAttr : ContainerAttr() {
    override fun parseAttrs(attrs: Map<String, String>): ViewAttr {
        val rowAttr = super.parseAttrs(attrs) as RowAttr
        flexbox = OTFlexBox.create(rowAttr)
        return rowAttr
    }

    override fun toString(): String {
        return "RowAttr(id = $id, width=$width, height = $height ,radius='$radius',flexbox='$flexbox')"
    }

    companion object {
        fun create(attrs: Map<String, String>): ViewAttr {
            return RowAttr().parseAttrs(attrs)
        }
    }
}
