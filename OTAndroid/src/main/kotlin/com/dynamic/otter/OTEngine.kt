package com.dynamic.otter

import android.content.Context
import android.view.View
import android.view.ViewGroup
import app.visly.stretch.Size
import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.render.node.NodeTreePrepare
import com.dynamic.otter.render.node.NodeUtils
import com.dynamic.otter.render.node.OTNode
import com.dynamic.otter.render.node.VDomNode
import com.dynamic.otter.render.view.OTViewTreeCreator
import com.dynamic.otter.render.view.basic.OTLayoutParams
import com.dynamic.otter.template.json.TemplateJsonParser
import com.dynamic.otter.utils.AssetsUtils
import com.dynamic.otter.utils.ScreenUtils
import kotlin.math.roundToInt

class OTEngine {
    internal lateinit var context: Context

    fun init(context: Context): OTEngine {
        this.context = context
        return this
    }

    fun buildTemplate(bizId: String, templateId: String, templatePath: String): TemplateContext {
        val template = OTTemplate(context, bizId, templateId, templatePath)
        return TemplateContext.create(template)
    }

    fun createAndroidView(
        templateContext: TemplateContext,
        viewport: OTViewPortSize = defaultViewPortSize()
    ): View? {
        val templateJson = AssetsUtils.parseAssetsToString(
            templateContext.context,
            templateContext.template.templatePath
        )
        val parsed = TemplateJsonParser.parse(templateJson)
        templateContext.viewIds.clear()
        templateContext.events = parsed.events
        val vDomNode = VDomNode.bind(parsed.root, templateContext)
        return createAndroidViewByVNode(vDomNode, viewport, templateContext)
    }

    private fun defaultViewPortSize() = OTViewPortSize(
        ScreenUtils.getScreenWidthPx(context),
        ScreenUtils.getScreenHeightPx(context)
    )

    private fun createAndroidViewByVNode(
        vDomNode: VDomNode,
        viewPortSize: OTViewPortSize,
        templateContext: TemplateContext
    ): View {
        val rootNode = createNodeTree(vDomNode, viewPortSize)
        templateContext.rootNode = rootNode
        templateContext.vDomNode = vDomNode
        return OTViewTreeCreator.buildAndroidView(templateContext)
    }

    fun createNodeTree(
        vDomNode: VDomNode,
        viewPortSize: OTViewPortSize
    ): OTNode = NodeTreePrepare.create(vDomNode, viewPortSize)

    fun relayout(templateContext: TemplateContext, viewport: OTViewPortSize) {
        val rootNode = templateContext.rootNode ?: return
        val rootView = templateContext.rootView ?: return
        NodeUtils.computeNodeTreeByPrepareView(
            rootNode,
            Size(viewport.width, viewport.height)
        )
        applyLayout(rootView, rootNode)
    }

    private fun applyLayout(view: View, node: OTNode) {
        val params = view.layoutParams
        val layout = node.stretchNode.layoutByPrepareView
        if (params is OTLayoutParams && layout != null) {
            val width = layout.width.roundToInt()
            val height = layout.height.roundToInt()
            val x = layout.x.roundToInt()
            val y = layout.y.roundToInt()
            if (params.width != width || params.height != height || params.x != x || params.y != y) {
                params.width = width
                params.height = height
                params.x = x
                params.y = y
                view.requestLayout()
            }
        }
        if (view is ViewGroup && !node.isListContainer()) {
            node.children.forEachIndexed { index, child ->
                if (index < view.childCount) {
                    applyLayout(view.getChildAt(index), child)
                }
            }
        }
    }

    data class OTViewPortSize(var width: Float?, var height: Float?)

    data class OTTemplate(
        val context: Context,
        var bizId: String,
        val templateId: String,
        val templatePath: String
    )

    companion object {
        val instance by lazy { OTEngine() }
    }
}
