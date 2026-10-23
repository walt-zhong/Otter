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
import com.dynamic.otter.template.json.ParsedNode

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
        fun bind(node: ParsedNode): VDomNode {
            val attr: ViewAttr? = when (node.viewName) {
                TemplateKey.COLUMN -> ColumnAttr.create(node.attrs)
                TemplateKey.ROW -> RowAttr.create(node.attrs)
                TemplateKey.TEXT -> TextAttr.create(node.attrs)
                TemplateKey.IMAGE -> ImageAttr.create(node.attrs)
                TemplateKey.SPACER -> SpacerAttr.create(node.attrs)
                TemplateKey.OT_LIST -> OTListAttr.create(node.attrs)
                TemplateKey.PROGRESS -> ProgressAttr.create(node.attrs)
                TemplateKey.ANIMATION -> AnimationViewAttr.create(node.attrs)
                else -> null
            }
            val virtualNode = VDomNode(node.id, node.viewName, attr)
            node.item?.let { item ->
                ListContainerData.listItemVNodeMap[virtualNode.id] = bind(item)
            }
            node.children.forEach { child ->
                virtualNode.children?.add(bind(child))
            }
            return virtualNode
        }
    }
}
