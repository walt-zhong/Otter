package com.dynamic.otter.render.view.worker

import android.view.View
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.OTEngine
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.view.basic.OTAbsoluteLayout
import com.dynamic.otter.render.view.basic.Text

class ViewEventWorker private constructor() : IEventWorker {
    override fun handleEvent(clickedView: View, paramJsonObj: JSONObject, itemData: JSONObject?) {
        val funMarker = paramJsonObj["fun"]
        when (funMarker) {
            "changeAttributes" -> {
                val funKey = paramJsonObj["key"]
                val rootView = OTEngine.instance.rootView
                val viewTempId = paramJsonObj["id"]
                val viewId = TemplateKey.RMap[viewTempId]
                val value = paramJsonObj["value"]
                val targetView = resolveTargetView(clickedView, rootView, viewId)

                when (funKey) {
                    "setText", "setTextStyle" -> {
                        if (targetView is Text) {
                            targetView.onBindData(value)
                        }
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
