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

    // TODO:涉及到多个页面模板路由时，需要使用map缓存起来每个模板的rootView
    var rootView: View? = null
    internal val render by lazy {
        RenderImpl()
    }

    fun init(context: Context): OTEngine {
        this.context = context
        return this
    }

    fun buildTemplate(bizId: String, templateId: String,templatePath:String): TemplateContext {
        val template = OTTemplate(context, bizId, templateId,templatePath)
        val templateContext = TemplateContext.create(template)
        return templateContext
    }

    fun createAndroidView(templateContext: TemplateContext): View? {
        val tContext: TemplateContext = templateContext
        // 获取工厂对象
        val factory = DocumentBuilderFactory.newInstance()
        // 通过DOM工厂获取DOMBuilder对象
        val builder = factory.newDocumentBuilder()
        // 解析XML输入流，得到Document对象，表示一个XML文档
        val document = builder.parse(
            tContext.context.resources.assets.open(templateContext.sdTemplate.templatePath)
        )

        // 获取文档中的次节点以及节点
        val documentElement = document.documentElement
        // 解析UI节点，属性
        val vLayoutNodeList = documentElement.getElementsByTagName(TemplateKey.LAYOUT_ROOT_NAME)
        // 解析事件
        val vEventNodeList = documentElement.getElementsByTagName(TemplateKey.EVENTS_ROOT_NAME)
        // 创建虚拟对象节点
        val vNode = VDomNode.create(vLayoutNodeList)
        // 解析事件
        DataBinding.instance.parseEvents(vEventNodeList)
        // 计算布局信息，TODO：这里的布局信息目前没有做缓存，后面优化可以添加引擎

        // 设置展示的视图窗口大小,默认为屏幕的宽高
        val vSDViewPortSize = OTViewPortSize(
            ScreenUtils.getScreenWidthPx(context),
            ScreenUtils.getScreenHeightPx(context)
        )

        val rootView = createAndroidViewByVNode(vNode, vSDViewPortSize, templateContext)
        return rootView
    }

    private fun createAndroidViewByVNode(
        vNode: VDomNode,
        vSDViewPortSize: OTViewPortSize,
        templateContext: TemplateContext
    ): View {
        val sdNode = createNodeTree(vNode, vSDViewPortSize)
        templateContext.rootNode = sdNode
        templateContext.vDomNode = vNode
        val rootView = render.createAndroidViewTree(templateContext)
        return rootView
    }

    fun createNodeTree(
        vNode: VDomNode,
        vSDViewPortSize: OTViewPortSize
    ): OTNode {
        val sdNode = render.prepare(vNode, vSDViewPortSize)
        return sdNode
    }


    data class OTViewPortSize(var width: Float?, var height: Float?) {
        override fun toString(): String {
            return "SDViewPortSize(width=$width, height=$height)"
        }
    }

    data class OTTemplate(
        val context: Context,
        var bizId: String, // 业务ID
        val templateId: String, // 模板ID
        val templatePath:String
    ) {
        // 模板的版本号，后续实现动态更新的关键
        var templateVersion: String = ""

        var isLocal: Boolean = false
    }

    companion object {
        val instance by lazy {
            OTEngine()
        }
    }

}