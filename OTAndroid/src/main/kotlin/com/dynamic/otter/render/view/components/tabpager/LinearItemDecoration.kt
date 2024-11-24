package com.dynamic.otter.render.view.components.tabpager

import android.graphics.Rect
import android.view.View
import androidx.recyclerview.widget.RecyclerView
import androidx.recyclerview.widget.RecyclerView.Adapter

class LinearItemDecoration(val adapter: TabAdapter<*>) :
    RecyclerView.ItemDecoration() {
    private var spaceVertical: Int = 0
    private var spaceHorizontal: Int = 0

    fun setSpaceVertical(spaceVertical: Int) {
        this.spaceVertical = spaceVertical
    }


    fun setSpaceHorizontal(spaceHorizontal: Int) {
        this.spaceHorizontal = spaceHorizontal
    }

    fun getSpaceVertical(): Int {
        return spaceVertical
    }

    fun getSpaceHorizontal(): Int {
        return spaceHorizontal
    }

    override fun getItemOffsets(
        outRect: Rect,
        view: View,
        parent: RecyclerView,
        state: RecyclerView.State
    ) {
        val viewHolder = parent.getChildViewHolder(view)
        val position = viewHolder.adapterPosition
        outRect.left = spaceHorizontal
        outRect.top = spaceVertical
        val itemCount = adapter.itemCount ?: 0
        val right = if (position == itemCount - 1) {
            spaceHorizontal
        } else {
            0
        }
        outRect.right = right
        outRect.bottom = spaceVertical
    }
}