package com.dynamic.otter.context

import android.content.Context
import android.view.View
import com.dynamic.otter.OTEngine
import com.dynamic.otter.render.node.OTNode
import com.dynamic.otter.render.node.VDomNode

class TemplateContext private constructor(
    val context: Context,
    val sdTemplate: OTEngine.OTTemplate
){
    /**
     * 当前模板的可见状态：
     * null 未赋值，非可见非不可见
     * true 可见
     * false 不可见
     */
    var isAppear: Boolean? = null

    /**
     * A soft or weak reference to a view
     */
    var rootView: View? = null

    /**
     * View Information about the virtual node tree associated with the template
     */
    var rootNode: OTNode? = null

    // 根据xml 中的Layout节点解析创建的虚拟节点树，
    var vDomNode:VDomNode? = null

    fun release(){
        rootNode?.release()
        rootNode = null
        rootView = null
    }

    companion object{
        fun create(
            sdTemplate: OTEngine.OTTemplate
        ):TemplateContext{
            return TemplateContext(sdTemplate.context,sdTemplate)
        }
    }
}