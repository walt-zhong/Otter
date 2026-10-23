package com.dynamic.otter.render.view.attr

import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.template.OTFlexBox

class OTListAttr : ViewAttr() {
    var data: String? = null
    var listDirection: String? = null
    var itemPadding: String? = null

    override fun parseAttrs(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
        val listAttr = super.parseAttrs(attrs, scope) as OTListAttr
        attrs.forEach { (attrName, rawValue) ->
            val attrValue = rawValue.extractExpValue(scope.data)
            when (attrName) {
                TemplateKey.ATTR_DATA -> listAttr.data = attrValue
                TemplateKey.ATTR_LIST_DIRECTION -> listAttr.listDirection = attrValue
                TemplateKey.ATTR_ITEM_PADDING -> listAttr.itemPadding = attrValue
            }
        }
        flexbox = OTFlexBox.create(listAttr)
        return listAttr
    }

    companion object {
        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            return OTListAttr().parseAttrs(attrs, scope)
        }
    }
}
