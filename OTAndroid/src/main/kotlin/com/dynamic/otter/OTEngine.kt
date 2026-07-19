package com.dynamic.otter

import android.content.Context
import android.view.View
import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.RenderImpl
import com.dynamic.otter.render.node.DataBinding
import com.dynamic.otter.render.node.OTNode
import com.dynamic.otter.render.node.VDomNode
import com.dynamic.otter.utils.ScreenUtils
import javax.xml.parsers.DocumentBuilderFactory

class OTEngine {
    internal lateinit var context: Context

    // TODO: 多页面模板路由时，用 map 缓存每个模板的 rootView
    var rootView: View? = null

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
        val document = parseTemplateDocument(templateContext)
        val documentElement = document.documentElement

        val layoutNodes = documentElement.getElementsByTagName(TemplateKey.LAYOUT_ROOT_NAME)
        val eventNodes = documentElement.getElementsByTagName(TemplateKey.EVENTS_ROOT_NAME)

        val vDomNode = VDomNode.create(layoutNodes)
        DataBinding.instance.parseEvents(eventNodes)

        // TODO: 布局结果可按模板缓存，当前每次全量计算
        val viewPortSize = defaultViewPortSize()
        return createAndroidViewByVNode(vDomNode, viewPortSize, templateContext)
    }

    private fun parseTemplateDocument(templateContext: TemplateContext) =
        DocumentBuilderFactory.newInstance()
            .newDocumentBuilder()
            .parse(
                templateContext.context.resources.assets.open(
                    templateContext.template.templatePath
                )
            )

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
        // 模板版本号，后续用于动态更新
        var templateVersion: String = ""
        var isLocal: Boolean = false
    }

    companion object {
        val instance by lazy { OTEngine() }
    }
}
