package com.dynamic.otter.render.view.worker

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
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
        if (paramJsonObj["fun"] == "back") {
            clickedView.context.findActivity()?.finish()
            return
        }
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

    private fun Context.findActivity(): Activity? {
        var current = this
        while (current is ContextWrapper) {
            if (current is Activity) {
                return current
            }
            current = current.baseContext
        }
        return null
    }

    companion object {
        val instance by lazy { NavEventWorker() }
    }
}
