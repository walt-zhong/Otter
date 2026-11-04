package com.dynamic.otter.render.view.components.tabpager.holder

import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.recyclerview.widget.RecyclerView

class MyFragmentViewHolder(container:FrameLayout) : RecyclerView.ViewHolder(container) {
    companion object{
        fun create(parent:ViewGroup):MyFragmentViewHolder{
            val container = FrameLayout(parent.context)
            container.layoutParams =
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )

            container.id = View.generateViewId()
            container.isSaveEnabled = false
            return MyFragmentViewHolder(container)
        }
    }

    fun getContainer():FrameLayout{
        return itemView as FrameLayout
    }
}