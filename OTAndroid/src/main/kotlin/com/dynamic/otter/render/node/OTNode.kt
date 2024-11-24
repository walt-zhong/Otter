package com.dynamic.otter.render.node

import android.view.View
import app.visly.stretch.Layout
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.view.attr.ViewAttr
import com.dynamic.otter.render.view.basic.capability.IReleaseCapability


class OTNode {
    fun release() {
        if (viewRoot is IReleaseCapability) {
            (viewRoot as IReleaseCapability).release()
        }
        viewRoot = null
        stretchNode.free()
        children?.forEach {
            it.release()
        }

        children?.clear()
        parentNode = null
    }

    var id = ""

    // 原生View引用
    var viewRoot: View? = null

    var attr: ViewAttr? = null

    /**
     * stretch: Flexbox计算引擎
     */
    lateinit var stretchNode: StretchNode

    // 初始时的布局
    var layoutByCratePrepare: Layout? = null

    // 绑定时的布局
    var layoutByBindData: Layout? = null

    /**
     * 是否是根节点
     */
    var isRoot: Boolean = false

    /**
     * view 节点的名字，比如Text,Image,Column,Row
     * 等用于后面识别建立对应的android 原生View
     */
    var viewName: String = ""


    /**
     * 父节点
     */
    var parentNode: OTNode? = null

    /**
     * 字节点
     */

    var children: MutableList<OTNode>? = null

    fun isListContainer(): Boolean {
        return viewName == TemplateKey.OT_LIST
    }
}