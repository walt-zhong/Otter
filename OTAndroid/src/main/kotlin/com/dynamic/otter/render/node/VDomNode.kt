package com.dynamic.otter.render.node

import com.dynamic.otter.data.ListContainerData
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.view.attr.AnimationViewAttr
import com.dynamic.otter.render.view.attr.ColumnAttr
import com.dynamic.otter.render.view.attr.ImageAttr
import com.dynamic.otter.render.view.attr.ProgressAttr
import com.dynamic.otter.render.view.attr.RowAttr
import com.dynamic.otter.render.view.attr.OTListAttr
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
            val layoutNode = nodeList.item(0) // Layout节点下只允许有一个孩子
            return createVirtualNode(layoutNode)
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
                TemplateKey.ANIMATION->AnimationViewAttr.create(attributes)
                else -> null
            }

            val virtualNode = initVirtualNode(id, nodeName, attr)
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
                if (childNodes.item(i).nodeType == Node.TEXT_NODE) {
                    continue
                }
                if (childNodes.item(i).nodeType == Node.COMMENT_NODE) {
                    continue
                }

                if (childNodes.item(i).nodeName == TemplateKey.LAYOUT_ITEM) {
                    // TODO：解析Item作为list view的item布局
                    val itemChildList = childNodes.item(i).childNodes
                    for (m in 0 until itemChildList.length) {
                        val itemNode = itemChildList.item(m)
                        if (itemNode.nodeType == Node.ELEMENT_NODE) {
                            if (itemNode.nodeType == Node.TEXT_NODE) {
                                continue
                            }
                            if (itemNode.nodeType == Node.COMMENT_NODE) {
                                continue
                            }

                            val vNode = createVirtualNode(itemNode)
                            ListContainerData.listItemVNodeMap[vDomNode.id] = vNode
                        }
                    }
                    continue
                }

                val child = createVirtualNode(childNodes.item(i))
                vDomNode.children?.add(child)
            }
        }

        private fun initVirtualNode(
            id: String,
            nodeName: String,
            attr: ViewAttr?
        ): VDomNode {
            return VDomNode(id, nodeName, attr)
        }
    }
}