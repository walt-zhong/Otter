package com.dynamic.otter.render.view.worker

import android.view.View
import android.widget.Toast
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.ExpansionCenter
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue

class NavEventWorker private constructor() : IEventWorker {
    override fun handleEvent(
        clickedView: View,
        paramJsonObj: JSONObject,
        itemData: JSONObject?,
        pageData: JSONObject?,
        rootView: View?,
        viewIds: Map<String, Int>
    ) {
        if (paramJsonObj["fun"] != "open") {
            return
        }
        val page = paramJsonObj["page"].toString().extractExpValue(itemData ?: pageData)
        val opener = ExpansionCenter.instance.pageOpener
        if (opener == null || page.isBlank() || page == "null") {
            Toast.makeText(clickedView.context, "这个页面还打不开", Toast.LENGTH_SHORT).show()
            return
        }
        opener.open(clickedView.context, page)
    }

    companion object {
        val instance by lazy { NavEventWorker() }
    }
}
