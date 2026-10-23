package com.dynamic.otter.render.view.attr

import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.template.OTFlexBox

class RowAttr : ContainerAttr() {
    override fun parseAttrs(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
        val rowAttr = super.parseAttrs(attrs, scope) as RowAttr
        flexbox = OTFlexBox.create(rowAttr)
        return rowAttr
    }

    companion object {
        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            return RowAttr().parseAttrs(attrs, scope)
        }
    }
}
