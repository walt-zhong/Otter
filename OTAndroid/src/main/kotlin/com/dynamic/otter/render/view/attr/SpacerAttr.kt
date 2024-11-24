package com.dynamic.otter.render.view.attr

import com.dynamic.otter.template.OTFlexBox
import org.w3c.dom.NamedNodeMap

class SpacerAttr : ViewAttr() {
    override fun parseAttrs(attrsMap: NamedNodeMap): ViewAttr {
        val spacerAttr = super.parseAttrs(attrsMap)
        flexbox = OTFlexBox.create(spacerAttr)
        return spacerAttr
    }

    companion object {
        fun create(attrsMap: NamedNodeMap): ViewAttr {
            return SpacerAttr().parseAttrs(attrsMap)
        }
    }
}