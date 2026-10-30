package com.dynamic.otter.render.view.attr

import app.visly.stretch.FlexDirection
import com.dynamic.otter.context.TemplateContext

class ColumnAttr : ContainerAttr() {
    override val flexDirection: FlexDirection = FlexDirection.Column

    companion object {
        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            return ColumnAttr().bind(attrs, scope)
        }
    }
}
