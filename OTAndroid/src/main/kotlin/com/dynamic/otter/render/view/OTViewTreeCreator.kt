package com.dynamic.otter.render.view

import android.content.Context
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.alibaba.fastjson.JSON
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.OTEngine
import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.node.DataBinding
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
import com.dynamic.otter.render.view.worker.UtilEventWorker
import com.dynamic.otter.render.view.worker.ViewEventWorker
import com.dynamic.otter.template.OTSize

object OTViewTreeCreator {
    fun buildAndroidView(templateContext: TemplateContext): View {
        val rootNode = templateContext.rootNode
            ?: throw IllegalStateException("TemplateContext.rootNode is null")
        val eventMap = DataBinding.instance.getEventMap()
        val rootView = createConfiguredView(
            context = templateContext.context,
            node = rootNode,
            eventMap = eventMap,
            itemData = null
        )
        buildChildViews(rootView as ViewGroup, rootNode, eventMap, itemData = null)
        return rootView
    }

    fun buildAndroidItemView(
        node: OTNode,
        context: Context,
        itemData: JSONObject
    ): View {
        val eventMap = DataBinding.instance.getEventMap()
        val itemView = createConfiguredView(context, node, eventMap, itemData)
        if (itemView is ViewGroup) {
            buildChildViews(itemView, node, eventMap, itemData)
        }
        return itemView
    }

    private fun createConfiguredView(
        context: Context,
        node: OTNode,
        eventMap: MutableMap<String, JSONObject>?,
        itemData: JSONObject?
    ): View {
        return OTViewFactory.createView<View>(context, node.viewName).apply {
            layoutParams = LayoutParamsUtils.createLayoutParams(
                node,
                node.stretchNode.layoutByPrepareView
            )
            setAttr(this, node, eventMap, itemData)
        }
    }

    private fun buildChildViews(
        parentView: ViewGroup,
        parentNode: OTNode,
        eventMap: MutableMap<String, JSONObject>?,
        itemData: JSONObject?
    ) {
        parentNode.children?.forEach { child ->
            val view = createConfiguredView(parentView.context, child, eventMap, itemData)
            // Item 树路径暂不支持列表方向/间距配置，保持原先固定垂直列表行为
            configureListContainerIfNeeded(view, child, useItemDefaults = itemData != null)
            parentView.addView(view)
            if (view is ViewGroup) {
                buildChildViews(view, child, eventMap, itemData)
            }
        }
    }

    /**
     * @param useItemDefaults when true, force vertical list with zero item padding
     * (legacy item-tree behavior).
     */
    private fun configureListContainerIfNeeded(
        view: View,
        node: OTNode,
        useItemDefaults: Boolean
    ) {
        if (!node.isListContainer() || view !is RecyclerView) {
            return
        }
        // TODO: nested list containers need more validation
        val listAttr = node.attr as OTListAttr
        val direction = if (useItemDefaults) {
            RecyclerView.VERTICAL
        } else {
            when (listAttr.listDirection) {
                TemplateKey.OT_HORIZONTAL -> RecyclerView.HORIZONTAL
                TemplateKey.OT_VERTICAL -> RecyclerView.VERTICAL
                else -> RecyclerView.VERTICAL
            }
        }
        val itemPadding = if (useItemDefaults) {
            0
        } else {
            OTSize.create(listAttr.itemPadding ?: "0").valueInt
        }
        val adapter = OTListAdapter(
            parentId = node.id,
            listDirection = direction,
            itemPadding = itemPadding
        )
        adapter.setData(JSON.parseArray(listAttr.data))
        view.layoutManager = LinearLayoutManager(view.context, direction, false)
        view.adapter = adapter
    }

    private fun setAttr(
        view: View,
        node: OTNode?,
        eventMap: MutableMap<String, JSONObject>?,
        itemData: JSONObject? = null
    ) {
        val attr = node?.attr
            ?: throw IllegalArgumentException("attr is null")

        view.id = attr.id

        // Keep root view for findViewById-based event updates
        if (node.isRoot && itemData == null) {
            OTEngine.instance.rootView = view
        }

        handleViewCommonAttr(view, attr, eventMap, itemData)
        handleTextAttr(view, attr, itemData)
        handleImageAttr(view, attr, itemData)
        handleProgressViewAttr(view, attr, itemData)
        handleAnimationAttr(view, attr, itemData)
    }

    private fun handleAnimationAttr(
        view: View,
        attr: ViewAttr,
        @Suppress("UNUSED_PARAMETER") itemData: JSONObject?
    ) {
        if (view is AnimationView && attr is AnimationViewAttr) {
            val jsonObj = JSONObject().apply {
                put(TemplateKey.ATTR_ANI_REPEAT_COUNT, attr.repeatCount)
                put(TemplateKey.ATTR_ANI_REPEAT_MODE, attr.repeatMode)
                put(TemplateKey.ATTR_ANI_AUTO_PLAY, attr.autoPlay)
                put(TemplateKey.ATTR_ANIMATION_SRC, attr.animationSrc)
            }
            view.onBindData(jsonObj)
        }
    }

    private fun handleViewCommonAttr(
        view: View,
        attr: ViewAttr,
        eventMap: MutableMap<String, JSONObject>?,
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

        if (attr.onClick != null) {
            view.setOnClickListener { clickedView ->
                val originFunStr = attr.onClick ?: return@setOnClickListener
                extractFunId(originFunStr).forEach { funId ->
                    handleEvent(clickedView, eventMap?.get(funId), itemData)
                }
            }
        }
    }

    private fun handleTextAttr(
        view: View,
        attr: ViewAttr?,
        itemData: JSONObject?
    ) {
        if (view !is Text || attr !is TextAttr) {
            return
        }
        // itemData != null means list item rebinding; expression must resolve against item JSON
        val textValue = if (itemData != null) {
            attr.text.extractExpValue(itemData)
        } else {
            attr.text
        }
        view.onBindStyle(attr)
        view.onBindData(textValue)
    }

    private fun handleImageAttr(
        view: View,
        attr: ViewAttr?,
        itemData: JSONObject?
    ) {
        if (view !is Image || attr !is ImageAttr) {
            return
        }
        val srcValue = if (itemData != null) {
            attr.src.extractExpValue(itemData)
        } else {
            attr.src
        }
        view.onBindStyle(attr)
        view.onBindData(srcValue)
    }

    private fun handleProgressViewAttr(
        view: View,
        attr: ViewAttr?,
        itemData: JSONObject?
    ) {
        if (view !is ProgressView || attr !is ProgressAttr) {
            return
        }
        val valueMin = if (itemData != null) {
            attr.valueMin.extractExpValue(itemData).toFloat()
        } else {
            attr.valueMin.toFloat()
        }
        val valueMax = if (itemData != null) {
            attr.valueMax.extractExpValue(itemData).toFloat()
        } else {
            attr.valueMax.toFloat()
        }
        val jsonObj = JSONObject().apply {
            put(TemplateKey.ATTR_VALUE_MIN, valueMin)
            put(TemplateKey.ATTR_VALUE_MAX, valueMax)
            put(TemplateKey.ATTR_ANIMATE_ENABLE, attr.animateEnable)
        }
        view.onBindData(jsonObj)
        view.onBindStyle(attr, itemData)
    }

    private fun handleEvent(
        clickedView: View,
        funJsonObj: JSONObject?,
        itemData: JSONObject? = null
    ) {
        val funClass = funJsonObj?.get("class")
        val params = funJsonObj?.get("params")
        when (funClass) {
            "view" -> {
                ViewEventWorker.instance.handleEvent(clickedView, params as JSONObject, itemData)
            }

            "util" -> {
                UtilEventWorker.instance.handleEvent(clickedView, params as JSONObject, itemData)
            }
        }
    }

    private fun extractFunId(funIdStr: String): MutableList<String> {
        val resultList: MutableList<String> = mutableListOf()
        val startIndex = funIdStr.indexOf("{")
        val endIndex = funIdStr.lastIndexOf("}")
        if (startIndex > 0 && endIndex > 0) {
            val tempFunIdStr = funIdStr.substring(startIndex + 1, endIndex)
            if (tempFunIdStr.contains(",")) {
                tempFunIdStr.split(",").forEach { resultList.add(it) }
            } else {
                resultList.add(tempFunIdStr)
            }
        }
        return resultList
    }
}
