package com.dynamic.otter.render.node

import android.view.View
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.view.attr.ViewAttr
import com.dynamic.otter.render.view.basic.capability.IReleaseCapability

class OTNode {
    var id = ""

    /** Native view reference for this node, if attached. */
    var viewRoot: View? = null

    var attr: ViewAttr? = null

    /** Stretch Flexbox node used for layout computation. */
    lateinit var stretchNode: StretchNode

    var isRoot: Boolean = false

    /** View type name such as Text, Image, Column, Row. */
    var viewName: String = ""

    var parentNode: OTNode? = null

    var children: MutableList<OTNode>? = null

    fun isListContainer(): Boolean = viewName == TemplateKey.OT_LIST

    fun release() {
        if (viewRoot is IReleaseCapability) {
            (viewRoot as IReleaseCapability).release()
        }
        viewRoot = null
        stretchNode.free()
        children?.forEach { it.release() }
        children?.clear()
        parentNode = null
    }
}
