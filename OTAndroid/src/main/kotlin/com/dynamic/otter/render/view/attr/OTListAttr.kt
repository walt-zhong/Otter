package com.dynamic.otter.render.view.attr

import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue

class OTListAttr : ViewAttr() {
    var data: String? = null
    var listDirection: String? = null
    var itemPadding: String? = null

    override fun applyOwn(name: String, raw: String, scope: TemplateContext) {
        val value = raw.extractExpValue(scope.data)
        when (name) {
            TemplateKey.ATTR_DATA -> data = value
            TemplateKey.ATTR_LIST_DIRECTION -> listDirection = value
            TemplateKey.ATTR_ITEM_PADDING -> itemPadding = value
        }
    }

    companion object {
        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            return OTListAttr().bind(attrs, scope)
        }
    }
}
