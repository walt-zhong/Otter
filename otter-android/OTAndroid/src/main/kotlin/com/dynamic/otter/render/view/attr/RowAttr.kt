package com.dynamic.otter.render.view.attr

import app.visly.stretch.FlexDirection
import com.dynamic.otter.context.TemplateContext

class RowAttr : ContainerAttr() {
    override val flexDirection: FlexDirection = FlexDirection.Row

    companion object {
        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            return RowAttr().bind(attrs, scope)
        }
    }
}
