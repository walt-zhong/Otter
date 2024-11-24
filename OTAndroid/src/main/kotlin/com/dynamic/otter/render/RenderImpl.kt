package com.dynamic.otter.render

import android.view.View
import com.dynamic.otter.OTEngine
import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.render.node.NodeTreePrepare
import com.dynamic.otter.render.node.OTNode
import com.dynamic.otter.render.node.VDomNode
import com.dynamic.otter.render.view.OTViewTreeCreator

class RenderImpl {

    fun prepare(vDomNode: VDomNode, viewPortSize: OTEngine.OTViewPortSize): OTNode {
        val rootNode = NodeTreePrepare.create(vDomNode, viewPortSize)
        return rootNode
    }

    fun createAndroidViewTree(templateContext: TemplateContext): View {
        return OTViewTreeCreator.buildAndroidView(templateContext)
    }
}