package com.dynamic.otter.data

import com.dynamic.otter.render.node.VDomNode

object ListContainerData {
    /**
     * Item template VDOM keyed by list container DSL id.
     */
    var listItemVNodeMap: MutableMap<String, VDomNode> = mutableMapOf()
}
