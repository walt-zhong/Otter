package com.dynamic.otter.context

import android.content.Context
import android.view.View
import com.dynamic.otter.OTEngine
import com.dynamic.otter.render.node.OTNode
import com.dynamic.otter.render.node.VDomNode

class TemplateContext private constructor(
    val context: Context,
    val template: OTEngine.OTTemplate
) {
    /**
     * 当前模板的可见状态：
     * null 未赋值
     * true 可见
     * false 不可见
     */
    var isAppear: Boolean? = null

    /**
     * Soft/weak reference candidate for the root view.
     */
    var rootView: View? = null

    /**
     * Layout-prepared node tree for this template.
     */
    var rootNode: OTNode? = null

    /**
     * Virtual DOM tree parsed from the template Layout section.
     */
    var vDomNode: VDomNode? = null

    fun release() {
        rootNode?.release()
        rootNode = null
        rootView = null
    }

    companion object {
        fun create(template: OTEngine.OTTemplate): TemplateContext {
            return TemplateContext(template.context, template)
        }
    }
}
