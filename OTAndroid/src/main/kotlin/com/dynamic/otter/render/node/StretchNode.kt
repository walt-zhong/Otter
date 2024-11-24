package com.dynamic.otter.render.node

import app.visly.stretch.Layout
import app.visly.stretch.Node
import app.visly.stretch.Size
import app.visly.stretch.Style
import com.dynamic.otter.render.view.attr.ViewAttr
import com.dynamic.otter.template.OTFlexBox

data class StretchNode(
    var node: Node? = null,
    var layoutByPrepareView: Layout? = null
) {

    fun free() {
        node?.safeFree()
    }
    companion object{
        fun createStretchNode(vDomNode: VDomNode): StretchNode {
            val stretchStyle = createStretchStyle(vDomNode.attr)
            val stretchNode = Node(vDomNode.id, stretchStyle, mutableListOf())
            return StretchNode(stretchNode, null)
        }

        private fun createStretchStyle(attr: ViewAttr?): Style {
            val style = Style()
            val flexBox = attr?.flexbox
            updateStyle(flexBox, style)
            style.safeInit()
            return style
        }

        private fun updateStyle(flexBox: OTFlexBox?, style: Style) {
            flexBox?.flexDirection?.let {
                style.flexDirection = it
            }

            flexBox?.sizeForDimension?.let {
                style.size = Size(it.width, it.height)
            }

            flexBox?.display?.let {
                style.display = it
            }

            flexBox?.justifyContent?.let {
                style.justifyContent = it
            }

            flexBox?.alignItems?.let {
                style.alignItems = it
            }

            flexBox?.paddingForDimension?.let {
                style.padding = it
            }
        }
    }
}