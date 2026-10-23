package com.dynamic.otter.render.view.attr

import com.dynamic.otter.template.OTFlexBox

class SpacerAttr : ViewAttr() {
    override fun parseAttrs(attrs: Map<String, String>): ViewAttr {
        val spacerAttr = super.parseAttrs(attrs)
        flexbox = OTFlexBox.create(spacerAttr)
        return spacerAttr
    }

    companion object {
        fun create(attrs: Map<String, String>): ViewAttr {
            return SpacerAttr().parseAttrs(attrs)
        }
    }
}
