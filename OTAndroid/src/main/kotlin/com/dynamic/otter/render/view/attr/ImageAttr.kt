package com.dynamic.otter.render.view.attr

import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.template.OTFlexBox

class ImageAttr : ViewAttr() {
    var src = ""
    var placeholder = ""

    override fun parseAttrs(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
        val imageAttr = super.parseAttrs(attrs, scope) as ImageAttr
        attrs.forEach { (attrName, rawValue) ->
            val attrValue = rawValue.extractExpValue(scope.data)
            when (attrName) {
                TemplateKey.ATTR_SRC -> src = attrValue
                TemplateKey.ATTR_PLACEHOLDER -> placeholder = attrValue
            }
        }
        flexbox = OTFlexBox.create(imageAttr)
        return imageAttr
    }

    companion object {
        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            return ImageAttr().parseAttrs(attrs, scope)
        }
    }
}
