package com.dynamic.otter.render.utils

import android.view.ViewGroup
import app.visly.stretch.Layout
import com.dynamic.otter.render.node.OTNode
import com.dynamic.otter.render.view.basic.OTLayoutParams
import kotlin.math.roundToInt

object LayoutParamsUtils {
    fun createLayoutParams(
        @Suppress("UNUSED_PARAMETER") node: OTNode,
        layout: Layout?
    ): OTLayoutParams {
        return if (layout != null) {
            OTLayoutParams(
                layout.width.roundToInt(),
                layout.height.roundToInt(),
                layout.x.roundToInt(),
                layout.y.roundToInt()
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
