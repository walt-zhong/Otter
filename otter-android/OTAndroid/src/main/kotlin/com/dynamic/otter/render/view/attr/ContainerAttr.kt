package com.dynamic.otter.render.view.attr

import app.visly.stretch.FlexDirection
import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey

open class ContainerAttr : ViewAttr() {
    var justifyContent: String? = null
    var alignItems: String? = null
    var flexWrap: String? = null
    open val flexDirection: FlexDirection? = null

    override fun applyOwn(name: String, raw: String, scope: TemplateContext) {
        when (name) {
            TemplateKey.FLEXBOX_ATTR_JUSTIFY_CONTENT -> justifyContent = raw
            TemplateKey.FLEXBOX_ATTR_ALIGN_ITEMS -> alignItems = raw
            TemplateKey.ATTR_FLEX_WRAP -> flexWrap = raw
        }
    }
}
