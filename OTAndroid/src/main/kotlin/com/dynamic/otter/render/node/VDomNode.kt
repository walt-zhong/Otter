package com.dynamic.otter.render.node

import com.dynamic.otter.data.ListContainerData
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.view.attr.AnimationViewAttr
import com.dynamic.otter.render.view.attr.ColumnAttr
import com.dynamic.otter.render.view.attr.ImageAttr
import com.dynamic.otter.render.view.attr.OTListAttr
import com.dynamic.otter.render.view.attr.ProgressAttr
import com.dynamic.otter.render.view.attr.RowAttr
import com.dynamic.otter.render.view.attr.SpacerAttr
import com.dynamic.otter.render.view.attr.TextAttr
import com.dynamic.otter.render.view.attr.ViewAttr
import org.w3c.dom.Node
import org.w3c.dom.NodeList

class VDomNode(
    var id: String = "0",
    var nodeName: String,
    var attr: ViewAttr?
) {
    var children: MutableList<VDomNode>? = mutableListOf()

    override fun toString(): String {
        return "VDomNode(id='$id', nodeName='$nodeName', children=$children), attr={$attr}"
    }

    companion object {
        fun create(nodeList: NodeList): VDomNode {
            // Layout root is expected to have a single element child
            return createVirtualNode(nodeList.item(0))
        }

        private fun createVirtualNode(layoutNode: Node): VDomNode {
            var attributes = layoutNode.attributes
            var nodeName = layoutNode.nodeName
            var node = layoutNode
            var id = "0"

            if (nodeName == TemplateKey.LAYOUT_ROOT_NAME) {
                for (i in 0 until layoutNode.childNodes.length) {
                    val item = layoutNode.childNodes.item(i)
                    if (item.nodeType == Node.ELEMENT_NODE) {
                        node = item
                        attributes = node.attributes
                        nodeName = node.nodeName
                    }
                }
            }

            if (attributes?.getNamedItem(TemplateKey.ATTR_ID) != null) {
                id = attributes.getNamedItem(TemplateKey.ATTR_ID).nodeValue
            }

            val attr: ViewAttr? = when (nodeName) {
                TemplateKey.COLUMN -> ColumnAttr.create(attributes)
                TemplateKey.ROW -> RowAttr.create(attributes)
                TemplateKey.TEXT -> TextAttr.create(attributes)
                TemplateKey.IMAGE -> ImageAttr.create(attributes)
                TemplateKey.SPACER -> SpacerAttr.create(attributes)
                TemplateKey.OT_LIST -> OTListAttr.create(attributes)
                TemplateKey.PROGRESS -> ProgressAttr.create(attributes)
                TemplateKey.ANIMATION -> AnimationViewAttr.create(attributes)
                else -> null
            }

            val virtualNode = VDomNode(id, nodeName, attr)
            initChildrenVirtual(node, virtualNode)
            return virtualNode
        }

        private fun initChildrenVirtual(
            layoutNode: Node?,
            vDomNode: VDomNode
        ) {
            if (layoutNode == null) {
                return
            }

            val childNodes = layoutNode.childNodes
            for (i in 0 until childNodes.length) {
                val child = childNodes.item(i)
                if (child.nodeType == Node.TEXT_NODE || child.nodeType == Node.COMMENT_NODE) {
                    continue
                }

                if (child.nodeName == TemplateKey.LAYOUT_ITEM) {
                    // Item subtree is the list item template, stored by list container id
                    val itemChildList = child.childNodes
                    for (m in 0 until itemChildList.length) {
                        val itemNode = itemChildList.item(m)
                        if (itemNode.nodeType == Node.ELEMENT_NODE) {
                            val itemVDom = createVirtualNode(itemNode)
                            ListContainerData.listItemVNodeMap[vDomNode.id] = itemVDom
                        }
                    }
                    continue
                }

                vDomNode.children?.add(createVirtualNode(child))
            }
        }
    }
}
