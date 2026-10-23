package com.dynamic.otter

import android.content.Context
import android.view.View
import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.render.RenderImpl
import com.dynamic.otter.render.node.OTNode
import com.dynamic.otter.render.node.VDomNode
import com.dynamic.otter.template.json.TemplateJsonParser
import com.dynamic.otter.utils.AssetsUtils
import com.dynamic.otter.utils.ScreenUtils

class OTEngine {
    internal lateinit var context: Context

    internal val render by lazy { RenderImpl() }

    fun init(context: Context): OTEngine {
        this.context = context
        return this
    }

    fun buildTemplate(bizId: String, templateId: String, templatePath: String): TemplateContext {
        val template = OTTemplate(context, bizId, templateId, templatePath)
        return TemplateContext.create(template)
    }

    fun createAndroidView(templateContext: TemplateContext): View? {
        val templateJson = AssetsUtils.parseAssetsToString(
            templateContext.context,
            templateContext.template.templatePath
        )
        val parsed = TemplateJsonParser.parse(templateJson)
        templateContext.viewIds.clear()
        templateContext.events = parsed.events
        val vDomNode = VDomNode.bind(parsed.root, templateContext)

        val viewPortSize = defaultViewPortSize()
        return createAndroidViewByVNode(vDomNode, viewPortSize, templateContext)
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
        return render.createAndroidViewTree(templateContext)
    }

    fun createNodeTree(
        vDomNode: VDomNode,
        viewPortSize: OTViewPortSize
    ): OTNode = render.prepare(vDomNode, viewPortSize)

    data class OTViewPortSize(var width: Float?, var height: Float?) {
        override fun toString(): String {
            return "OTViewPortSize(width=$width, height=$height)"
        }
    }

    data class OTTemplate(
        val context: Context,
        var bizId: String,
        val templateId: String,
        val templatePath: String
    ) {
        var templateVersion: String = ""
        var isLocal: Boolean = false
    }

    companion object {
        val instance by lazy { OTEngine() }
    }
}
