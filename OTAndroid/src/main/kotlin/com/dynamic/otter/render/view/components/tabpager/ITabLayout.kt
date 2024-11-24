package com.dynamic.otter.render.view.components.tabpager

import android.view.View

interface ITabLayout {
    fun <T : View> getView(): T

    fun <T : ITabLayout> setIndicatorView(indicator: IViewIndicator)
}