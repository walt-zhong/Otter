package com.dynamic.otter.render.view

import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.alibaba.fastjson.JSON
import com.alibaba.fastjson.JSONArray
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.OTEngine
import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.node.OTNode
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.render.utils.LayoutParamsUtils
import com.dynamic.otter.render.view.attr.AnimationViewAttr
import com.dynamic.otter.render.view.attr.ImageAttr
import com.dynamic.otter.render.view.attr.OTListAttr
import com.dynamic.otter.render.view.attr.ProgressAttr
import com.dynamic.otter.render.view.attr.TextAttr
import com.dynamic.otter.render.view.attr.ViewAttr
import com.dynamic.otter.render.view.basic.AnimationView
import com.dynamic.otter.render.view.basic.Image
import com.dynamic.otter.render.view.basic.ProgressView
import com.dynamic.otter.render.view.basic.Text
import com.dynamic.otter.render.view.basic.adapter.OTListAdapter
import com.dynamic.otter.render.view.factory.OTViewFactory
import com.dynamic.otter.render.view.worker.NavEventWorker
import com.dynamic.otter.render.view.worker.UtilEventWorker
import com.dynamic.otter.render.view.worker.ViewEventWorker
import com.dynamic.otter.template.OTSize

object OTViewTreeCreator {
    fun buildAndroidView(templateContext: TemplateContext): View {
        val rootNode = templateContext.rootNode
            ?: throw IllegalStateException("TemplateContext.rootNode is null")
        val rootView = createConfiguredView(templateContext, rootNode, itemData = null)
        templateContext.rootView = rootView
        buildChildViews(rootView as ViewGroup, rootNode, templateContext, itemData = null)
        return rootView
    }

    fun buildAndroidItemView(
        node: OTNode,
        templateContext: TemplateContext,
        itemData: JSONObject
    ): View {
        val itemView = createConfiguredView(templateContext, node, itemData)
        if (itemView is ViewGroup) {
            buildChildViews(itemView, node, templateContext, itemData)
        }
        return itemView
    }

    private fun createConfiguredView(
        templateContext: TemplateContext,
        node: OTNode,
        itemData: JSONObject?
    ): View {
        return OTViewFactory.createView<View>(templateContext.context, node.viewName).apply {
            layoutParams = LayoutParamsUtils.createLayoutParams(node.stretchNode.layoutByPrepareView)
            setAttr(this, node, templateContext, itemData)
        }
    }

    private fun buildChildViews(
        parentView: ViewGroup,
        parentNode: OTNode,
        templateContext: TemplateContext,
        itemData: JSONObject?
    ) {
        parentNode.children.forEach { child ->
            val view = createConfiguredView(templateContext, child, itemData)
            configureListContainerIfNeeded(view, child, templateContext)
            parentView.addView(view)
            if (view is ViewGroup && !child.isListContainer()) {
                buildChildViews(view, child, templateContext, itemData)
            }
        }
    }

    private fun configureListContainerIfNeeded(
        view: View,
        node: OTNode,
        templateContext: TemplateContext
    ) {
        if (!node.isListContainer() || view !is RecyclerView) {
            return
        }
        val itemTemplate = node.itemTemplate ?: return
        val listAttr = node.attr as OTListAttr
        val direction = when (listAttr.listDirection) {
            TemplateKey.OT_HORIZONTAL -> RecyclerView.HORIZONTAL
            else -> RecyclerView.VERTICAL
        }
        val itemPadding = OTSize.create(listAttr.itemPadding ?: "0").valueInt
        val listLayout = node.stretchNode.layoutByPrepareView
        val viewport = if (direction == RecyclerView.HORIZONTAL) {
            OTEngine.OTViewPortSize(width = null, height = listLayout?.height)
        } else {
            OTEngine.OTViewPortSize(width = listLayout?.width, height = null)
        }
        val adapter = OTListAdapter(
            itemTemplate = itemTemplate,
            viewport = viewport,
            templateContext = templateContext,
            listDirection = direction,
            itemPadding = itemPadding
        )
        adapter.setData(JSON.parseArray(listAttr.data) ?: JSONArray())
        view.layoutManager = LinearLayoutManager(view.context, direction, false)
        view.adapter = adapter
    }

    private fun setAttr(
        view: View,
        node: OTNode?,
        templateContext: TemplateContext,
        itemData: JSONObject? = null
    ) {
        val attr = node?.attr ?: throw IllegalArgumentException("attr is null")
        view.id = attr.id
        handleViewCommonAttr(view, attr, templateContext, itemData)
        when {
            view is Text && attr is TextAttr -> bindText(view, attr, itemData)
            view is Image && attr is ImageAttr -> view.onBindData(attr.src.resolve(itemData))
            view is ProgressView && attr is ProgressAttr -> {
                view.onBindData(ProgressView.ProgressBind(attr, itemData))
                view.onBindStyle(attr, itemData)
            }
            view is AnimationView && attr is AnimationViewAttr -> view.onBindData(attr)
        }
    }

    private fun bindText(view: Text, attr: TextAttr, itemData: JSONObject?) {
        view.onBindStyle(attr)
        view.onBindData(attr.text.resolve(itemData))
    }

    private fun String.resolve(itemData: JSONObject?): String {
        return if (itemData != null) extractExpValue(itemData) else this
    }

    private fun handleViewCommonAttr(
        view: View,
        attr: ViewAttr,
        templateContext: TemplateContext,
        itemData: JSONObject?
    ) {
        view.setBackgroundWithRadius(viewAttr = attr)

        if (attr.radius != null
            || attr.leftBottomRadius != null
            || attr.leftTopRadius != null
            || attr.rightTopRadius != null
            || attr.rightBottomRadius != null
        ) {
            view.setViewRoundCornerAndBorder(attr)
        }

        val clickNames = attr.onClick?.split(',')?.map { it.trim() }?.filter { it.isNotEmpty() }
        if (!clickNames.isNullOrEmpty()) {
            view.setOnClickListener { clickedView ->
                clickNames.forEach { name ->
                    dispatchEvent(clickedView, templateContext.events[name], itemData, templateContext)
                }
            }
        }
    }

    private fun dispatchEvent(
        clickedView: View,
        event: JSONObject?,
        itemData: JSONObject?,
        templateContext: TemplateContext
    ) {
        val params = event?.get("params") as? JSONObject ?: return
        when (event.get("class")) {
            "view" -> ViewEventWorker.instance.handleEvent(
                clickedView,
                params,
                itemData,
                templateContext.data,
                templateContext.rootView,
                templateContext.viewIds
            )

            "nav" -> NavEventWorker.instance.handleEvent(
                clickedView,
                params,
                itemData,
                templateContext.data,
                templateContext.rootView,
                templateContext.viewIds
            )

            "util" -> UtilEventWorker.instance.handleEvent(
                clickedView,
                params,
                itemData,
                templateContext.data,
                templateContext.rootView,
                templateContext.viewIds
            )
        }
    }
}
