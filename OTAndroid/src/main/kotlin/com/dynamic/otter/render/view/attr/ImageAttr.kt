package com.dynamic.otter.render.view.attr

import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.template.OTFlexBox

class ImageAttr : ViewAttr() {
    var src = ""
    var placeholder = ""

    override fun parseAttrs(attrs: Map<String, String>): ViewAttr {
        attrs.forEach { (attrName, rawValue) ->
            when (attrName) {
                TemplateKey.ATTR_SRC -> src = rawValue.extractExpValue()
                TemplateKey.ATTR_PLACEHOLDER -> placeholder = rawValue.extractExpValue()
            }
        }
        val imageAttr = super.parseAttrs(attrs) as ImageAttr
        flexbox = OTFlexBox.create(imageAttr)
        return imageAttr
    }

    override fun toString(): String {
        return "ImageAttr(id = $id, width=$width, height = $height ,src='$src',flexbox='$flexbox')"
    }

    companion object {
        fun create(attrs: Map<String, String>): ViewAttr {
            return ImageAttr().parseAttrs(attrs)
        }
    }
}
