package com.dynamic.otter.render.view.components.tabpager.adapter

import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentManager
import androidx.lifecycle.Lifecycle
import androidx.recyclerview.widget.RecyclerView
import com.dynamic.otter.render.view.components.tabpager.TabViewHolder

abstract class FragPageAdapter<T> : BaseFragPageAdapter<T, TabViewHolder>,ITabPageAdapter<T> {
    constructor(fragmentActivity: FragmentActivity):super(fragmentActivity)
    constructor(fragment: Fragment):super(fragment)
    constructor(fragmentManager: FragmentManager,lifecycle: Lifecycle):super(fragmentManager, lifecycle)

    override fun <W : RecyclerView.Adapter<*>?> getPageAdapter(): W {
        return this as W
    }
}