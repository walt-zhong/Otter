package com.dynamic.otter.render.node

import app.visly.stretch.Size
import com.dynamic.otter.OTEngine

object NodeTreePrepare {
    fun create(vDomNode: VDomNode, viewPortSize: OTEngine.OTViewPortSize): OTNode {
        val rootNode = createOtNode(vDomNode, parent = null)
        rootNode.isRoot = true
        NodeUtils.computeNodeTreeByPrepareView(
            rootNode,
            size = Size(viewPortSize.width, viewPortSize.height)
        )
        return rootNode
    }

    private fun createOtNode(
        vDomNode: VDomNode,
        parent: OTNode?
    ): OTNode {
        val node = OTNode()
        node.parentNode = parent
        node.id = vDomNode.id
        node.viewName = vDomNode.nodeName
        node.attr = vDomNode.attr
        node.stretchNode = StretchNode.createStretchNode(vDomNode)

        vDomNode.children?.forEach { childVDom ->
            val childNode = createOtNode(childVDom, node)
            if (node.children == null) {
                node.children = mutableListOf()
            }
            node.children?.add(childNode)
            childNode.stretchNode.node?.let { stretchChild ->
                node.stretchNode.node?.safeAddChild(stretchChild)
            }
        }

        return node
    }
}
