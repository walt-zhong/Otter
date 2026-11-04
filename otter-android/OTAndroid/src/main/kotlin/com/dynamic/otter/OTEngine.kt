package com.dynamic.otter

import android.content.Context
import android.view.View
import java.io.File
import android.view.ViewGroup
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.render.node.NodeTreePrepare
import com.dynamic.otter.render.node.OTNode
import com.dynamic.otter.render.node.VDomNode
import com.dynamic.otter.render.view.basic.adapter.WrapTextHeight
import com.dynamic.otter.render.view.OTViewTreeCreator
import com.dynamic.otter.render.view.basic.Column
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

    internal fun readyContext(): Context? {
        if (!::context.isInitialized) {
            return null
        }
        return context
    }

    fun buildTemplate(
        bizId: String,
        templateId: String,
        templatePath: String,
        fileRoot: File? = null
    ): TemplateContext {
        val template = OTTemplate(context, bizId, templateId, templatePath, fileRoot)
        return TemplateContext.create(template)
    }

    fun createAndroidView(
        templateContext: TemplateContext,
        viewport: OTViewPortSize = defaultViewPortSize()
    ): View? {
        val template = templateContext.template
        val templateJson = if (template.fileRoot != null) {
            AssetsUtils.readRelative(template.fileRoot, template.templatePath)
        } else {
            AssetsUtils.parseAssetsToString(templateContext.context, template.templatePath)
        }
        val parsed = TemplateJsonParser.parse(templateJson)
        templateContext.parsed = parsed
        templateContext.viewport = viewport
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
    ): OTNode {
        val root = NodeTreePrepare.create(vDomNode, viewPortSize)
        WrapTextHeight.settle(root, JSONObject(), viewPortSize)
        return root
    }

    fun rebind(templateContext: TemplateContext) {
        val rootView = templateContext.rootView ?: return
        val parsed = templateContext.parsed ?: return
        val viewport = templateContext.viewport ?: return
        val savedIds = templateContext.viewIds.toMap()
        val savedVDom = templateContext.vDomNode
        val previousRoot = templateContext.rootNode
        val vDomNode = VDomNode.bind(parsed.root, templateContext)
        val rootNode = try {
            createNodeTree(vDomNode, viewport)
        } catch (error: RuntimeException) {
            templateContext.viewIds.clear()
            templateContext.viewIds.putAll(savedIds)
            templateContext.vDomNode = savedVDom
            throw error
        }
        OTViewTreeCreator.rebindViews(rootView, rootNode, templateContext)
        applyLayout(rootView, rootNode)
        templateContext.vDomNode = vDomNode
        templateContext.rootNode = rootNode
        templateContext.rootView = rootView
        if (previousRoot != null && previousRoot !== rootNode) {
            retireNode(previousRoot)
        }
    }

    fun relayout(templateContext: TemplateContext, viewport: OTViewPortSize) {
        templateContext.viewport = viewport
        val rootNode = templateContext.rootNode ?: return
        val rootView = templateContext.rootView ?: return
        WrapTextHeight.settle(rootNode, JSONObject(), viewport)
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
        if (node.isListContainer()) {
            return
        }
        val container = templateChildrenOf(view) ?: return
        val count = minOf(container.childCount, node.children.size)
        for (index in 0 until count) {
            applyLayout(container.getChildAt(index), node.children[index])
        }
    }

    private fun templateChildrenOf(view: View): ViewGroup? {
        val scrolled = (view as? Column)?.scrollContent
        if (scrolled != null) {
            return scrolled
        }
        return view as? ViewGroup
    }

    private fun retireNode(node: OTNode) {
        clearViewRoots(node)
        node.release()
    }

    private fun clearViewRoots(node: OTNode) {
        node.viewRoot = null
        node.children.forEach { clearViewRoots(it) }
    }

    data class OTViewPortSize(var width: Float?, var height: Float?)

    data class OTTemplate(
        val context: Context,
        var bizId: String,
        val templateId: String,
        val templatePath: String,
        val fileRoot: File? = null
    )

    companion object {
        val instance by lazy { OTEngine() }
    }
}
