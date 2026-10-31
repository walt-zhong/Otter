package com.dynamic.otter.render.view

import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.alibaba.fastjson.JSON
import com.alibaba.fastjson.JSONArray
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.ExpansionCenter
import com.dynamic.otter.OTEngine
import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.node.OTNode
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.render.utils.LayoutParamsUtils
import com.dynamic.otter.render.view.attr.ContainerAttr
import com.dynamic.otter.render.view.attr.AnimationViewAttr
import com.dynamic.otter.render.view.attr.CheckBoxAttr
import com.dynamic.otter.render.view.attr.ImageAttr
import com.dynamic.otter.render.view.attr.InputAttr
import com.dynamic.otter.render.view.attr.OTListAttr
import com.dynamic.otter.render.view.attr.ProgressAttr
import com.dynamic.otter.render.view.attr.RadioAttr
import com.dynamic.otter.render.view.attr.SwitchAttr
import com.dynamic.otter.render.view.attr.TextAttr
import com.dynamic.otter.render.view.attr.ViewAttr
import com.dynamic.otter.render.view.basic.AnimationView
import com.dynamic.otter.render.view.basic.CheckBox
import com.dynamic.otter.render.view.basic.Image
import com.dynamic.otter.render.view.basic.Input
import com.dynamic.otter.render.view.basic.OTLayoutParams
import com.dynamic.otter.render.view.basic.ProgressView
import com.dynamic.otter.render.view.basic.Radio
import com.dynamic.otter.render.view.basic.Switch
import com.dynamic.otter.render.view.basic.Text
import com.dynamic.otter.render.view.basic.adapter.OTListAdapter
import com.dynamic.otter.render.view.factory.OTViewFactory
import com.dynamic.otter.render.view.worker.ListEventWorker
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
            placeItemEnd(itemView, node, itemData)
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
        attr.idName?.let { view.tag = it }
        val background = attr.background
        val resolvedBackground = background?.resolve(itemData)
        if (resolvedBackground != background) {
            attr.background = resolvedBackground
        }
        try {
            handleViewCommonAttr(view, attr, templateContext, itemData)
        } finally {
            attr.background = background
        }
        when {
            view is Text && attr is TextAttr -> bindText(view, attr, itemData)
            view is Input && attr is InputAttr -> bindInput(view, attr, itemData)
            view is CheckBox && attr is CheckBoxAttr -> bindCheckBox(view, attr, itemData)
            view is Radio && attr is RadioAttr -> bindRadio(view, attr, itemData)
            view is Switch && attr is SwitchAttr -> bindSwitch(view, attr, itemData)
            view is Image && attr is ImageAttr -> view.onBindData(attr.src.resolve(itemData))
            view is ProgressView && attr is ProgressAttr -> {
                view.onBindData(ProgressView.ProgressBind(attr, itemData))
                view.onBindStyle(attr, itemData)
            }
            view is AnimationView && attr is AnimationViewAttr -> view.onBindData(attr)
        }
    }

    private fun bindText(view: Text, attr: TextAttr, itemData: JSONObject?) {
        val color = attr.textColor
        val resolved = color.resolve(itemData)
        if (resolved != color) {
            attr.textColor = resolved
        }
        try {
            view.onBindStyle(attr)
            view.onBindData(attr.text.resolve(itemData))
        } finally {
            attr.textColor = color
        }
    }

    private fun bindInput(view: Input, attr: InputAttr, itemData: JSONObject?) {
        val color = attr.textColor
        val hint = attr.hint
        val hintColor = attr.hintColor
        val resolvedColor = color.resolve(itemData)
        val resolvedHint = hint.resolve(itemData)
        val resolvedHintColor = hintColor.resolve(itemData)
        if (resolvedColor != color) {
            attr.textColor = resolvedColor
        }
        if (resolvedHint != hint) {
            attr.hint = resolvedHint
        }
        if (resolvedHintColor != hintColor) {
            attr.hintColor = resolvedHintColor
        }
        try {
            view.onBindStyle(attr)
            view.onBindData(attr.text.resolve(itemData))
        } finally {
            attr.textColor = color
            attr.hint = hint
            attr.hintColor = hintColor
        }
    }

    private fun bindCheckBox(view: CheckBox, attr: CheckBoxAttr, itemData: JSONObject?) {
        val label = attr.text
        val color = attr.textColor
        val tint = attr.tint
        val resolvedLabel = label.resolve(itemData)
        val resolvedColor = color.resolve(itemData)
        val resolvedTint = tint.resolve(itemData)
        val resolvedChecked = attr.checkedSource.resolve(itemData) == "true"
        if (resolvedLabel != label) {
            attr.text = resolvedLabel
        }
        if (resolvedColor != color) {
            attr.textColor = resolvedColor
        }
        if (resolvedTint != tint) {
            attr.tint = resolvedTint
        }
        val previousChecked = attr.checked
        attr.checked = resolvedChecked
        try {
            view.onBindStyle(attr)
            view.onBindData(resolvedChecked)
        } finally {
            attr.text = label
            attr.textColor = color
            attr.tint = tint
            attr.checked = previousChecked
        }
    }

    private fun bindRadio(view: Radio, attr: RadioAttr, itemData: JSONObject?) {
        val label = attr.text
        val color = attr.textColor
        val tint = attr.tint
        val group = attr.group
        val resolvedLabel = label.resolve(itemData)
        val resolvedColor = color.resolve(itemData)
        val resolvedTint = tint.resolve(itemData)
        val resolvedGroup = attr.groupSource.resolve(itemData)
        val resolvedChecked = attr.checkedSource.resolve(itemData) == "true"
        if (resolvedLabel != label) {
            attr.text = resolvedLabel
        }
        if (resolvedColor != color) {
            attr.textColor = resolvedColor
        }
        if (resolvedTint != tint) {
            attr.tint = resolvedTint
        }
        if (resolvedGroup != group) {
            attr.group = resolvedGroup
        }
        val previousChecked = attr.checked
        attr.checked = resolvedChecked
        try {
            view.onBindStyle(attr)
            view.onBindData(resolvedChecked)
        } finally {
            attr.text = label
            attr.textColor = color
            attr.tint = tint
            attr.group = group
            attr.checked = previousChecked
        }
    }

    private fun bindSwitch(view: Switch, attr: SwitchAttr, itemData: JSONObject?) {
        val label = attr.text
        val color = attr.textColor
        val tint = attr.tint
        val resolvedLabel = label.resolve(itemData)
        val resolvedColor = color.resolve(itemData)
        val resolvedTint = tint.resolve(itemData)
        val resolvedChecked = attr.checkedSource.resolve(itemData) == "true"
        if (resolvedLabel != label) {
            attr.text = resolvedLabel
        }
        if (resolvedColor != color) {
            attr.textColor = resolvedColor
        }
        if (resolvedTint != tint) {
            attr.tint = resolvedTint
        }
        val previousChecked = attr.checked
        attr.checked = resolvedChecked
        try {
            view.onBindStyle(attr)
            view.onBindData(resolvedChecked)
        } finally {
            attr.text = label
            attr.textColor = color
            attr.tint = tint
            attr.checked = previousChecked
        }
    }

    private fun placeItemEnd(view: ViewGroup, node: OTNode, itemData: JSONObject) {
        val justify = (node.attr as? ContainerAttr)?.justifyContent ?: return
        if (!justify.startsWith("$")) {
            return
        }
        if (justify.resolve(itemData) != "end") {
            return
        }
        val parentWidth = view.layoutParams?.width ?: return
        if (parentWidth <= 0) {
            return
        }
        for (index in 0 until view.childCount) {
            val child = view.getChildAt(index)
            val params = child.layoutParams as? OTLayoutParams ?: continue
            if (params.width <= 0) {
                continue
            }
            params.x = parentWidth - params.x - params.width
        }
    }

    private fun String.resolve(itemData: JSONObject?): String {
        return if (itemData != null) extractExpValue(itemData) else this
    }

    private fun JSONObject.toStringMap(): Map<String, String> {
        val map = linkedMapOf<String, String>()
        for (key in keys) {
            val value = get(key)
            if (value is String) {
                map[key] = value
            }
        }
        return map
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
                val data = itemData
                if (data != null) {
                    ExpansionCenter.instance.itemClick?.onItemClick(data.toStringMap())
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

            "list" -> ListEventWorker.instance.handleEvent(
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
