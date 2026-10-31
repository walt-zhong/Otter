package com.dynamic.otter.render.view.worker

import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.Toast
import androidx.recyclerview.widget.RecyclerView
import com.alibaba.fastjson.JSONArray
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.render.view.basic.Input
import com.dynamic.otter.render.view.basic.OTAbsoluteLayout
import com.dynamic.otter.render.view.basic.adapter.OTListAdapter

class ListEventWorker private constructor() : IEventWorker {
    override fun handleEvent(
        clickedView: View,
        paramJsonObj: JSONObject,
        itemData: JSONObject?,
        pageData: JSONObject?,
        rootView: View?,
        viewIds: Map<String, Int>
    ) {
        if (paramJsonObj["fun"] != "append") {
            return
        }
        val input = resolveTargetView(
            clickedView,
            rootView,
            viewIds[paramJsonObj.getString("from")]
        ) as? Input ?: return
        val text = input.text?.toString()?.trim().orEmpty()
        if (text.isEmpty()) {
            val empty = paramJsonObj.getString("empty")
            if (!empty.isNullOrEmpty()) {
                Toast.makeText(clickedView.context, empty, Toast.LENGTH_SHORT).show()
            }
            return
        }
        val listView = resolveTargetView(
            clickedView,
            rootView,
            viewIds[paramJsonObj.getString("id")]
        ) as? RecyclerView ?: return
        val adapter = listView.adapter as? OTListAdapter ?: return
        val item = JSONObject()
        paramJsonObj.getJSONObject("item")?.keys?.forEach { key ->
            item[key] = paramJsonObj.getJSONObject("item").get(key)
        }
        item[paramJsonObj.getString("field")] = text
        val stored = pageData?.get(paramJsonObj.getString("data"))
        if (stored is JSONArray) {
            stored.add(item)
        }
        adapter.appendItem(item)
        val last = adapter.itemCount - 1
        listView.post { listView.smoothScrollToPosition(last) }
        input.onBindData("")
        val manager = input.context.getSystemService(InputMethodManager::class.java)
        manager?.hideSoftInputFromWindow(input.windowToken, 0)
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
        val instance by lazy { ListEventWorker() }
    }
}
