package com.dynamic.otter.render.utils

import android.view.View
import android.view.ViewGroup
import app.visly.stretch.Layout
import com.dynamic.otter.render.node.OTNode
import com.dynamic.otter.render.view.basic.OTLayoutParams


object LayoutParamsUtils {
    fun createLayoutParams(
        sdNode: OTNode,
        layout: Layout?
    ): OTLayoutParams {
        return if (layout != null) {
            val width = layout.width.toInt()
            val height = layout.height.toInt()
            OTLayoutParams(
                width,
                height,
                layout.x.toInt(),
                layout.y.toInt()
            )
        } else {
            OTLayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                0,
                0
            )
        }
    }

    fun updateLayoutParams(
        view: View,
        layout: Layout
    ) {
        val layoutParams = view.layoutParams
        val width = layout.width.toInt()
        val height = layout.height.toInt()

        layoutParams.width = width
        layoutParams.height = height

        if (layoutParams is OTLayoutParams) {
            layoutParams.x = layout.x.toInt()
            layoutParams.y = layout.y.toInt()
        }

        view.layoutParams = layoutParams
    }
}