package com.dynamic.otter.render.node

import app.visly.stretch.Size
import com.dynamic.otter.OTEngine

object NodeTreePrepare {
    fun create(vDomNode: VDomNode, sdViewPortSize: OTEngine.OTViewPortSize): OTNode {
        val rootNode = createSDNode(vDomNode, null)
        rootNode.isRoot = true
        NodeUtils.computeNodeTreeByPrepareView(
            rootNode,
            size = Size(
                sdViewPortSize.width,
                sdViewPortSize.height
            )
        )

        return rootNode
    }

    private fun createSDNode(
        vDomNode: VDomNode,
        sdParentSDNode: OTNode?
    ): OTNode {
        val sdNode = OTNode()
        sdNode.parentNode = sdParentSDNode
        sdNode.id = vDomNode.id
        sdNode.viewName = vDomNode.nodeName
        sdNode.attr = vDomNode.attr
        sdNode.stretchNode = StretchNode.createStretchNode(vDomNode)
        vDomNode.children?.forEach { curVD ->
            val sdChildNode = createSDNode(curVD, sdNode)
            if (sdNode.children == null) {
                sdNode.children = mutableListOf()
            }

            sdNode.children?.add(sdChildNode)
            sdChildNode.stretchNode.node?.let {
                sdNode.stretchNode.node?.safeAddChild(it)
            }
        }

        return sdNode
    }
}