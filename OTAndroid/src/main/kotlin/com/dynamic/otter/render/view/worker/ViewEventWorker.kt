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
                // 通过资源Map找到真实的生成android的View之后的id
                val viewId = TemplateKey.RMap[viewTempId]
                val value = paramJsonObj["value"]
                var sdView: View? = null
                if (viewId != null) {
                    if (clickedView.id == viewId) { // 如果点击的View和需要修改属性的View一致，则直接更新
                        sdView = clickedView
                    } else if (rootView is OTAbsoluteLayout) {
                        sdView = rootView.findViewById(viewId)
                    }
                }

                when (funKey) {
                    "setText", "setTextStyle" -> {
                        if (sdView is Text) {
                            sdView.onBindData(value)
                        }
                    }
                }
            }
        }
    }

    companion object {
        val instance by lazy {
            ViewEventWorker()
        }
    }
}