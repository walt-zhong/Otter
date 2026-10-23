package com.dynamic.otter.render.view.attr

import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.template.OTFlexBox

class ColumnAttr : ContainerAttr() {
    override fun parseAttrs(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
        val columnAttr = super.parseAttrs(attrs, scope) as ColumnAttr
        flexbox = OTFlexBox.create(columnAttr)
        return columnAttr
    }

    companion object {
        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            return ColumnAttr().parseAttrs(attrs, scope)
        }
    }
}
