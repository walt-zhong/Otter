package com.dynamic.otter.render.view.attr

import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey

open class ContainerAttr : ViewAttr() {
    var justifyContent: String? = null
    var alignItems: String? = null

    override fun parseAttrs(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
        super.parseAttrs(attrs, scope)
        justifyContent = attrs[TemplateKey.FLEXBOX_ATTR_JUSTIFY_CONTENT]
        alignItems = attrs[TemplateKey.FLEXBOX_ATTR_ALIGN_ITEMS]
        return this
    }
}
