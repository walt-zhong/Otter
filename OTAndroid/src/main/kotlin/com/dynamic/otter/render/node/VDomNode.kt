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
    val children = mutableListOf<VDomNode>()
    var item: VDomNode? = null

    companion object {
        fun bind(node: ParsedNode, scope: TemplateContext): VDomNode {
            val attr = createAttr(node.viewName, node.attrs, scope)
            val virtualNode = VDomNode(node.id, node.viewName, attr)
            node.item?.let { item ->
                virtualNode.item = bind(item, scope)
            }
            node.children.forEach { child ->
                virtualNode.children.add(bind(child, scope))
            }
            return virtualNode
        }

        private fun createAttr(
            viewName: String,
            attrs: Map<String, String>,
            scope: TemplateContext
        ): ViewAttr? = when (viewName) {
            TemplateKey.COLUMN -> ColumnAttr.create(attrs, scope)
            TemplateKey.ROW -> RowAttr.create(attrs, scope)
            TemplateKey.TEXT -> TextAttr.create(attrs, scope)
            TemplateKey.IMAGE -> ImageAttr.create(attrs, scope)
            TemplateKey.SPACER -> SpacerAttr.create(attrs, scope)
            TemplateKey.OT_LIST -> OTListAttr.create(attrs, scope)
            TemplateKey.PROGRESS -> ProgressAttr.create(attrs, scope)
            TemplateKey.ANIMATION -> AnimationViewAttr.create(attrs, scope)
            else -> null
        }
    }
}
