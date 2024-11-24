package com.dynamic.otter.render.view

import android.content.Context
import android.util.Log
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
import com.dynamic.otter.render.view.attr.ProgressAttr
import com.dynamic.otter.render.view.attr.OTListAttr
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
        val sdNode = templateContext.rootNode
        val context = templateContext.context
        val eventMap = DataBinding.instance.getEventMap()
        val layout = sdNode?.stretchNode?.layoutByPrepareView
        val rootView = sdNode?.let {
            OTViewFactory
                .createView<View>(context, it.viewName)
                .apply {
                    this.layoutParams = LayoutParamsUtils.createLayoutParams(sdNode, layout)
                }.apply {
                    setAttr(this, sdNode, eventMap)
                }
        }

        buildAndroidChildView(rootView as ViewGroup, sdNode, eventMap)
        return rootView
    }

    fun buildAndroidItemView(
        sdNode: OTNode,
        context: Context,
        itemData: JSONObject
    ): View {
        val layout = sdNode.stretchNode.layoutByPrepareView
        val eventMap = DataBinding.instance.getEventMap()
        val itemView = OTViewFactory.createView<View>(context, sdNode.viewName)
            .apply {
                this.layoutParams = LayoutParamsUtils.createLayoutParams(sdNode, layout)
            }.apply {
                setAttr(this, sdNode, eventMap, itemData)
            }

        if (itemView is ViewGroup) {
            buildAndroidChildItemView(itemView, sdNode, eventMap, itemData)
        }
        return itemView
    }

    private fun buildAndroidChildItemView(
        itemView: ViewGroup,
        sdNode: OTNode,
        eventMap: MutableMap<String, JSONObject>,
        itemData: JSONObject
    ) {
        sdNode.children?.forEach { child ->
            val view = OTViewFactory
                .createView<View>(itemView.context, child.viewName)
                .apply {
                    this.layoutParams = LayoutParamsUtils.createLayoutParams(
                        child,
                        child.stretchNode.layoutByPrepareView
                    )
                }.apply {
                    setAttr(this, child, eventMap, itemData)
                }

            // TODO： 如果还有嵌套的列表容器，需要进一步开发验证
            if (child.isListContainer()) {
                if (view is RecyclerView) {
                    val adapter = OTListAdapter(child.id)
                    val data = ((child.attr) as OTListAttr).data
                    adapter.setData(JSON.parseArray(data))
                    view.layoutManager = LinearLayoutManager(
                        view.context, RecyclerView.VERTICAL,
                        false
                    )
                    view.adapter = adapter
                }
            }
            itemView.addView(view)
            if (view is ViewGroup) {
                buildAndroidChildItemView(view, child, eventMap, itemData)
            }
        }
    }

    private fun setAttr(
        view: View,
        sdNode: OTNode?,
        eventMap: MutableMap<String, JSONObject>?,
        itemData: JSONObject? = null
    ) {
        val attr = sdNode?.attr
        if (attr != null) {
            view.id = attr.id
        } else {
            throw IllegalArgumentException("attr is null")
        }

        // 保存DSL模板的根节点生成的View,如果根布局是ViewGroup类型的，绑定事件的时候可以通过
        // ViewGroup的findViewById方法找到需要更新的View
        if (sdNode.isRoot && itemData == null) {
            OTEngine.instance.rootView = view
        }

        // 处理View的公共属性
        handleViewCommonAttr(view, attr, eventMap, itemData)

        // 处理文字控件相关的属性
        handleTextAttr(view, attr, itemData)

        // 处理图片控件相关的属性
        handleImageAttr(view, attr, itemData)

        // 处理进度条控件相关的属性
        handleProgressViewAttr(view, attr, itemData)

        // 处理动画相关的属性
        handleAnimationAttr(view,attr,itemData)
    }

    private fun handleAnimationAttr(view: View, attr: ViewAttr, itemData: JSONObject?) {
        if(view is AnimationView && attr is AnimationViewAttr){
            val repeatCountValue = attr.repeatCount
            val repeatModeValue = attr.repeatMode
            val autoPlayValue = attr.autoPlay
            val animationSrcValue = attr.animationSrc
            val jsonObj = JSONObject()
            jsonObj[TemplateKey.ATTR_ANI_REPEAT_COUNT] = repeatCountValue
            jsonObj[TemplateKey.ATTR_ANI_REPEAT_MODE] = repeatModeValue
            jsonObj[TemplateKey.ATTR_ANI_AUTO_PLAY] = autoPlayValue
            jsonObj[TemplateKey.ATTR_ANIMATION_SRC] = animationSrcValue

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

        // 设置圆角或者边框，这里的属性是所有view都需要的
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
                val originFunStr = attr.onClick
                if (originFunStr != null) {
                    val funIdList = extractFunId(originFunStr)
                    funIdList.forEach { funId ->
                        val funJsonObj = eventMap?.get(funId)
                        handleEvent(clickedView, funJsonObj, itemData)
                    }
                }
            }
        }
    }

    private fun handleTextAttr(
        view: View,
        attr: ViewAttr?,
        itemData: JSONObject?
    ) {
        if (view is Text && attr is TextAttr) {
            Log.d("zhongxj", "setAttr===>${attr.text}")
            // 如果ItemData不为空，说明是容器控件的item View,需要重新绑定数据，TODO：不严谨，需要优化
            if (itemData != null) {
                // 更新ItemView的文字
                val itemStr = attr.text.extractExpValue(itemData)
                view.onBindStyle(attr)
                view.onBindData(itemStr)
            } else {
                view.onBindStyle(attr)
                view.onBindData(attr.text)
            }
        }
    }

    private fun handleImageAttr(
        view: View,
        attr: ViewAttr?,
        itemData: JSONObject?
    ) {
        if (view is Image && attr is ImageAttr) {
            if (itemData != null) {
                // 更新ItemView的图片，如果是itemView中的View,则attr是原来的表达式，因为刚开始建立
                // view 树的时候并没有数据可以绑定
                val srcStr = attr.src.extractExpValue(itemData)
                view.onBindStyle(attr)
                view.onBindData(srcStr)
            } else {
                view.onBindStyle(attr)
                view.onBindData(attr.src)
            }
        }
    }

    private fun handleProgressViewAttr(
        view: View,
        attr: ViewAttr?,
        itemData: JSONObject?
    ) {
        if (view is ProgressView && attr is ProgressAttr) {
            if (itemData != null) {
                val valueMin = attr.valueMin.extractExpValue(itemData).toFloat()
                val valueMax = attr.valueMax.extractExpValue(itemData).toFloat()
                val animateEnable = attr.animateEnable

                val jsonObj = JSONObject()
                jsonObj[TemplateKey.ATTR_VALUE_MIN] = valueMin
                jsonObj[TemplateKey.ATTR_VALUE_MAX] = valueMax
                jsonObj[TemplateKey.ATTR_ANIMATE_ENABLE] = animateEnable

                view.onBindData(jsonObj)
            } else {
                val valueMin = attr.valueMin.toFloat()
                val valueMax = attr.valueMax.toFloat()
                val animateEnable = attr.animateEnable

                val jsonObj = JSONObject()
                jsonObj[TemplateKey.ATTR_VALUE_MIN] = valueMin
                jsonObj[TemplateKey.ATTR_VALUE_MAX] = valueMax
                jsonObj[TemplateKey.ATTR_ANIMATE_ENABLE] = animateEnable

                view.onBindData(jsonObj)
            }

            view.onBindStyle(attr, itemData)
        }
    }

    private fun handleEvent(
        clickedView: View,
        funJsonObj: JSONObject?,
        itemData: JSONObject? = null
    ) {
        val funClass = funJsonObj?.get("class") // 方法分类
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
                tempFunIdStr.split(",").forEach {
                    resultList.add(it)
                }
            } else {
                resultList.add(tempFunIdStr)
            }
        }

        return resultList
    }

    private fun buildAndroidChildView(
        parentView: ViewGroup,
        sdNode: OTNode,
        eventMap: MutableMap<String, JSONObject>?
    ) {
        sdNode.children?.forEach { child ->
            val view = OTViewFactory
                .createView<View>(parentView.context, child.viewName)
                .apply {
                    this.layoutParams = LayoutParamsUtils.createLayoutParams(
                        child,
                        child.stretchNode.layoutByPrepareView
                    )
                }.apply {
                    setAttr(this, child, eventMap)
                }
            if (child.isListContainer()) {
                if (view is RecyclerView) {
                    val sdListAttr = (child.attr) as OTListAttr
                    val itemPadding = sdListAttr.itemPadding ?: "0"
                    val direction: Int = when (sdListAttr.listDirection) {
                        TemplateKey.OT_HORIZONTAL -> {
                            RecyclerView.HORIZONTAL
                        }

                        TemplateKey.OT_VERTICAL -> {
                            RecyclerView.VERTICAL
                        }

                        else -> {
                            RecyclerView.VERTICAL
                        }
                    }

                    val adapter = OTListAdapter(
                        parentId = child.id,
                        listDirection = direction,
                        itemPadding = OTSize.create(itemPadding).valueInt
                    )
                    val data = sdListAttr.data
                    adapter.setData(JSON.parseArray(data))
                    view.layoutManager = LinearLayoutManager(
                        view.context,
                        direction,
                        false
                    )


                    view.adapter = adapter
                }
            }
            parentView.addView(view)
            if (view is ViewGroup) {
                buildAndroidChildView(view, child, eventMap)
            }
        }
    }
}