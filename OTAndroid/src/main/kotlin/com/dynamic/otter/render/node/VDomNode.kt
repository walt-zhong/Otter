package com.dynamic.otter.render.node

import com.dynamic.otter.context.TemplateContext
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
    var item: VDomNode? = null

    companion object {
        fun bind(node: ParsedNode, scope: TemplateContext): VDomNode {
            val attr: ViewAttr? = when (node.viewName) {
                TemplateKey.COLUMN -> ColumnAttr.create(node.attrs, scope)
                TemplateKey.ROW -> RowAttr.create(node.attrs, scope)
                TemplateKey.TEXT -> TextAttr.create(node.attrs, scope)
                TemplateKey.IMAGE -> ImageAttr.create(node.attrs, scope)
                TemplateKey.SPACER -> SpacerAttr.create(node.attrs, scope)
                TemplateKey.OT_LIST -> OTListAttr.create(node.attrs, scope)
                TemplateKey.PROGRESS -> ProgressAttr.create(node.attrs, scope)
                TemplateKey.ANIMATION -> AnimationViewAttr.create(node.attrs, scope)
                else -> null
            }
            val virtualNode = VDomNode(node.id, node.viewName, attr)
            node.item?.let { item ->
                virtualNode.item = bind(item, scope)
            }
            node.children.forEach { child ->
                virtualNode.children?.add(bind(child, scope))
            }
            return virtualNode
        }
    }
}
