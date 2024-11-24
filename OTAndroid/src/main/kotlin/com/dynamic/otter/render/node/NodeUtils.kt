package com.dynamic.otter.render.node

import app.visly.stretch.Layout
import app.visly.stretch.Size

object NodeUtils {
    fun computeNodeTreeByPrepareView(
        sdNode: OTNode,
        size: Size<Float?>
    ) {
        val stretchNode = sdNode.stretchNode.node
            ?: throw IllegalArgumentException("stretch node is null,please check!")
        val layout = stretchNode.safeComputeLayout(size)
        composeStretchNodeByPrepareView(sdNode, layout)
    }

    private fun composeStretchNodeByPrepareView(sdNode: OTNode, layout: Layout) {
        val stretchNode = sdNode.stretchNode.node
            ?: throw IllegalArgumentException("stretch node is null, please check!")
        layout.id = stretchNode.id
        sdNode.stretchNode.layoutByPrepareView = layout
        sdNode.children?.forEachIndexed { index, sdNode ->
            composeStretchNodeByPrepareView(sdNode, layout.children[index])
        }
    }
}