package com.dynamic.otter.render.view.worker

import android.view.View
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.nav.PageParams
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.render.view.basic.Input
import com.dynamic.otter.render.view.basic.OTAbsoluteLayout
import com.dynamic.otter.render.view.basic.Text
import com.dynamic.otter.render.view.basic.capability.ICheckable
import com.dynamic.otter.render.view.basic.capability.IDataBindingCapability

class ViewEventWorker private constructor() : IEventWorker {
    override fun handleEvent(
        clickedView: View,
        paramJsonObj: JSONObject,
        itemData: JSONObject?,
        pageData: JSONObject?,
        rootView: View?,
        viewIds: Map<String, Int>
    ) {
        if (paramJsonObj["fun"] != "changeAttributes") {
            return
        }
        val scope = PageParams.merge(pageData, itemData)
        val targetId = viewIds[paramJsonObj["id"]]
        val targetView = resolveTargetView(clickedView, rootView, targetId)
        when (paramJsonObj["key"]) {
            "setText" -> {
                if (targetView == null || (targetView !is Text && targetView !is Input)) {
                    return
                }
                val value = paramJsonObj["value"]
                val text = if (value is String) {
                    value.extractExpValue(scope)
                } else {
                    value?.toString().orEmpty()
                }
                (targetView as IDataBindingCapability).onBindData(text)
            }

            "setTextStyle" -> {
                if (targetView == null || (targetView !is Text && targetView !is Input)) {
                    return
                }
                (targetView as IDataBindingCapability).onBindData(paramJsonObj["value"])
            }

            "setChecked" -> {
                val value = paramJsonObj["value"]
                val resolved = if (value is String) {
                    value.extractExpValue(scope)
                } else {
                    value
                }
                paramJsonObj["id"].toString().split(",").forEach { name ->
                    val box = resolveTargetView(clickedView, rootView, viewIds[name.trim()])
                    if (box is ICheckable) {
                        box.onBindData(resolved)
                    }
                }
            }
        }
    }

    private fun resolveTargetView(
        clickedView: View,
        rootView: View?,
        viewId: Int?
    ): View? {
        if (viewId == null) {
            return null
        }
        return when {
            clickedView.id == viewId -> clickedView
            rootView is OTAbsoluteLayout -> rootView.findViewById(viewId)
            else -> null
        }
    }

    companion object {
        val instance by lazy { ViewEventWorker() }
    }
}
