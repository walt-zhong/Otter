package com.dynamic.otter.render.view.worker

import android.view.View
import android.widget.Toast
import androidx.recyclerview.widget.RecyclerView
import com.alibaba.fastjson.JSONArray
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.expression.ExpressionWrapper
import com.dynamic.otter.nav.Ime
import com.dynamic.otter.nav.PageParams
import com.dynamic.otter.render.view.OTViewTreeCreator
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
        when (paramJsonObj.getString("fun")) {
            "append" -> append(clickedView, paramJsonObj, pageData, rootView, viewIds)
            "update" -> update(clickedView, paramJsonObj, itemData, pageData, rootView, viewIds)
            "remove" -> remove(clickedView, paramJsonObj, itemData, pageData, rootView, viewIds)
        }
    }

    private fun append(
        clickedView: View,
        paramJsonObj: JSONObject,
        pageData: JSONObject?,
        rootView: View?,
        viewIds: Map<String, Int>
    ) {
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
        if (stored is JSONArray && !adapter.isSameData(stored)) {
            stored.add(item)
        }
        adapter.appendItem(item)
        val last = adapter.itemCount - 1
        listView.post { listView.smoothScrollToPosition(last) }
        OTViewTreeCreator.suppressInputChange(input) {
            input.onBindData("")
        }
        Ime.dismiss(input)
    }

    private fun update(
        clickedView: View,
        paramJsonObj: JSONObject,
        itemData: JSONObject?,
        pageData: JSONObject?,
        rootView: View?,
        viewIds: Map<String, Int>
    ) {
        val index = resolveIndex(paramJsonObj, itemData, pageData) ?: return
        val item = paramJsonObj.getJSONObject("item") ?: return
        val fields = stringFields(item, itemData, pageData)
        val listView = resolveTargetView(
            clickedView,
            rootView,
            viewIds[paramJsonObj.getString("id")]
        ) as? RecyclerView ?: return
        val adapter = listView.adapter as? OTListAdapter ?: return
        if (index !in 0 until adapter.itemCount) {
            return
        }
        adapter.updateItem(index, fields)
        mirrorFields(pageData, adapter, index, fields)
    }

    private fun remove(
        clickedView: View,
        paramJsonObj: JSONObject,
        itemData: JSONObject?,
        pageData: JSONObject?,
        rootView: View?,
        viewIds: Map<String, Int>
    ) {
        val index = resolveIndex(paramJsonObj, itemData, pageData) ?: return
        val listView = resolveTargetView(
            clickedView,
            rootView,
            viewIds[paramJsonObj.getString("id")]
        ) as? RecyclerView ?: return
        val adapter = listView.adapter as? OTListAdapter ?: return
        if (index !in 0 until adapter.itemCount) {
            return
        }
        val mirrored = foreignPageArray(pageData, adapter)
        adapter.removeItem(index)
        if (mirrored != null && index < mirrored.size) {
            mirrored.removeAt(index)
        }
    }

    private fun resolveIndex(
        params: JSONObject,
        itemData: JSONObject?,
        pageData: JSONObject?
    ): Int? {
        if (!params.containsKey("index")) {
            return null
        }
        val rawValue = params.get("index") ?: return null
        val raw = rawValue.toString()
        if (raw.isBlank()) {
            return null
        }
        val scope = PageParams.merge(pageData, itemData)
        val evaluated = ExpressionWrapper.instance.getResult(raw, scope)?.toString().orEmpty()
        if (evaluated.isBlank()) {
            return null
        }
        return evaluated.toIntOrNull()
    }

    private fun stringFields(
        item: JSONObject,
        itemData: JSONObject?,
        pageData: JSONObject?
    ): Map<String, String> {
        val scope = PageParams.merge(pageData, itemData)
        val fields = linkedMapOf<String, String>()
        for (key in item.keys) {
            val value = item.get(key) ?: continue
            fields[key] = if (value is String) {
                ExpressionWrapper.instance.getResult(value, scope)?.toString().orEmpty()
            } else {
                value.toString()
            }
        }
        return fields
    }

    private fun mirrorFields(
        pageData: JSONObject?,
        adapter: OTListAdapter,
        index: Int,
        fields: Map<String, String>
    ) {
        val array = foreignPageArray(pageData, adapter) ?: return
        if (index !in 0 until array.size) {
            return
        }
        val item = array.getJSONObject(index) ?: return
        fields.forEach { (key, value) -> item[key] = value }
    }

    private fun foreignPageArray(pageData: JSONObject?, adapter: OTListAdapter): JSONArray? {
        if (pageData == null) {
            return null
        }
        var foreign: JSONArray? = null
        var count = 0
        for (key in pageData.keys) {
            val value = pageData.get(key) as? JSONArray ?: continue
            if (adapter.isSameData(value)) {
                return null
            }
            foreign = value
            count += 1
        }
        return if (count == 1) foreign else null
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
