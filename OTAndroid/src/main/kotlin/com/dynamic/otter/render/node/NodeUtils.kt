package com.dynamic.otter.render.node

import app.visly.stretch.Layout
import app.visly.stretch.Size

object NodeUtils {
    fun computeNodeTreeByPrepareView(node: OTNode, size: Size<Float?>) {
        val stretchNode = node.stretchNode.node
            ?: throw IllegalArgumentException("stretch node is null")
        applyPreparedLayout(node, stretchNode.safeComputeLayout(size))
    }

    private fun applyPreparedLayout(node: OTNode, layout: Layout) {
        val stretchNode = node.stretchNode.node
            ?: throw IllegalArgumentException("stretch node is null")
        layout.id = stretchNode.id
        node.stretchNode.layoutByPrepareView = layout
        node.children.forEachIndexed { index, child ->
            applyPreparedLayout(child, layout.children[index])
        }
    }
}
