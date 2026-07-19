package com.dynamic.otter.render.utils

import android.view.ViewGroup
import app.visly.stretch.Layout
import com.dynamic.otter.render.node.OTNode
import com.dynamic.otter.render.view.basic.OTLayoutParams

object LayoutParamsUtils {
    fun createLayoutParams(
        @Suppress("UNUSED_PARAMETER") node: OTNode,
        layout: Layout?
    ): OTLayoutParams {
        return if (layout != null) {
            OTLayoutParams(
                layout.width.toInt(),
                layout.height.toInt(),
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
}
