package com.dynamic.otter.render.view.components.tabpager.adapter

import androidx.recyclerview.widget.RecyclerView
import com.dynamic.otter.render.view.components.tabpager.TabViewHolder

interface ITabPageAdapter<T>:IBaseTabPageAdapter<T,TabViewHolder> {
    fun <W : RecyclerView.Adapter<*>?> getPageAdapter(): W
}