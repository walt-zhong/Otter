package com.dynamic.otter.render.view.attr

import android.view.View
import app.visly.stretch.FlexDirection
import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey

class ColumnAttr : ContainerAttr() {
    override val flexDirection: FlexDirection = FlexDirection.Column
    var scroll: Boolean = false

    override fun applyOwn(name: String, raw: String, scope: TemplateContext) {
        when (name) {
            TemplateKey.ATTR_SCROLL -> scroll = raw == "true"
            else -> super.applyOwn(name, raw, scope)
        }
    }

    companion object {
        private val scrollingViewIds = HashSet<Int>()

        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            val attr = ColumnAttr()
            attr.bind(attrs, scope)
            if (attr.scroll) {
                if (attr.id == 0) {
                    attr.id = View.generateViewId()
                }
                scrollingViewIds.add(attr.id)
            }
            return attr
        }

        fun isScrolling(viewId: Int): Boolean {
            return viewId != 0 && scrollingViewIds.contains(viewId)
        }
    }
}
