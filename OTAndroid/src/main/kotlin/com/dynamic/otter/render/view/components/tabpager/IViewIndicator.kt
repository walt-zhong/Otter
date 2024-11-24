package com.dynamic.otter.render.view.components.tabpager

import android.view.View

interface IViewIndicator {
    fun <T:View> getView():T
    fun getIndicator():Indicator?
}