package com.dynamic.otter.render.view.components.tabpager

import android.view.View

interface IViewHolder {
    fun <T : View> getView(viewId:Int):T
}