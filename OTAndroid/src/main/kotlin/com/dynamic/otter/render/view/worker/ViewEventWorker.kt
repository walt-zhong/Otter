package com.dynamic.otter.render.view.worker

import android.view.View
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.render.view.basic.OTAbsoluteLayout
import com.dynamic.otter.render.view.basic.Text
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue

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
        val targetId = viewIds[paramJsonObj["id"]]
        val targetView = resolveTargetView(clickedView, rootView, targetId)
        if (targetView !is Text) {
            return
        }
        when (paramJsonObj["key"]) {
            "setText" -> {
                val value = paramJsonObj["value"]
                val text = if (value is String) {
                    value.extractExpValue(itemData ?: pageData)
                } else {
                    value?.toString().orEmpty()
                }
                targetView.onBindData(text)
            }

            "setTextStyle" -> targetView.onBindData(paramJsonObj["value"])
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
