package com.dynamic.otter.nav

import android.view.View
import android.view.ViewGroup
import android.widget.CompoundButton
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.render.view.basic.Input
import com.dynamic.otter.render.view.basic.OTItemView
import com.dynamic.otter.render.view.basic.capability.ICheckable

internal class ListScroll(val position: Int, val offset: Int)

internal object PageForm {
    fun snapshot(root: View?, data: JSONObject?) {
        if (root == null || data == null) {
            return
        }
        writeControls(root, data)
    }

    fun captureScroll(root: View?, into: MutableMap<String, ListScroll>) {
        if (root == null) {
            return
        }
        val found = linkedMapOf<String, ListScroll>()
        readScroll(root, "0", found)
        into.clear()
        into.putAll(found)
    }

    fun restore(root: View?, data: JSONObject?) {
        if (root == null || data == null) {
            return
        }
        applyControls(root, data)
    }

    fun restoreScroll(root: View?, scrolls: Map<String, ListScroll>) {
        if (root == null || scrolls.isEmpty()) {
            return
        }
        root.post {
            if (root.parent == null) {
                return@post
            }
            applyScroll(root, "0", scrolls)
        }
    }

    private fun writeControls(view: View, data: JSONObject) {
        if (view is RecyclerView || view is OTItemView) {
            return
        }
        val id = view.tag as? String
        if (!id.isNullOrEmpty()) {
            when (view) {
                is Input -> data[id] = view.text?.toString().orEmpty()
                is CompoundButton -> data[id] = view.isChecked
            }
        }
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                writeControls(view.getChildAt(index), data)
            }
        }
    }

    private fun applyControls(view: View, data: JSONObject) {
        if (view is RecyclerView || view is OTItemView) {
            return
        }
        val id = view.tag as? String
        if (!id.isNullOrEmpty() && data.containsKey(id)) {
            val value = data.get(id)
            when {
                view is Input && value is String -> view.onBindData(value)
                view is ICheckable && value is Boolean -> view.onBindData(value)
            }
        }
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                applyControls(view.getChildAt(index), data)
            }
        }
    }

    private fun readScroll(view: View, path: String, into: MutableMap<String, ListScroll>) {
        if (view is RecyclerView) {
            val manager = view.layoutManager as? LinearLayoutManager ?: return
            val position = manager.findFirstVisibleItemPosition()
            if (position == RecyclerView.NO_POSITION) {
                return
            }
            val child = manager.findViewByPosition(position)
            val start = if (manager.orientation == LinearLayoutManager.HORIZONTAL) {
                (child?.left ?: 0) - view.paddingLeft
            } else {
                (child?.top ?: 0) - view.paddingTop
            }
            into[path] = ListScroll(position, start)
            return
        }
        if (view !is ViewGroup || view is OTItemView) {
            return
        }
        for (index in 0 until view.childCount) {
            readScroll(view.getChildAt(index), "$path/$index", into)
        }
    }

    private fun applyScroll(view: View, path: String, scrolls: Map<String, ListScroll>) {
        if (view is RecyclerView) {
            val scroll = scrolls[path] ?: return
            val manager = view.layoutManager as? LinearLayoutManager ?: return
            manager.scrollToPositionWithOffset(scroll.position, scroll.offset)
            return
        }
        if (view !is ViewGroup || view is OTItemView) {
            return
        }
        for (index in 0 until view.childCount) {
            applyScroll(view.getChildAt(index), "$path/$index", scrolls)
        }
    }
}
