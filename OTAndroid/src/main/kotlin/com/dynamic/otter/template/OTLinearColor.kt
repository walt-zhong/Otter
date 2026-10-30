package com.dynamic.otter.template

import android.graphics.Shader
import android.graphics.drawable.GradientDrawable
import android.widget.TextView
import com.dynamic.otter.render.view.drawable.LinearColorGradientDrawable

class OTLinearColor(
    val direction: GradientDrawable.Orientation,
    val colors: MutableList<OTColor>
) {
    fun createShader(view: TextView): Shader? {
        return StyleConverter.createLinearGradient(
            view.layoutParams.width.toFloat(),
            view.layoutParams.height.toFloat(),
            direction,
            colorArray()
        )
    }

    fun createDrawable() = LinearColorGradientDrawable(direction, colorArray())

    private fun colorArray(): IntArray {
        if (colors.size == 1) {
            val value = colors[0].value()
            return intArrayOf(value, value)
        }
        return IntArray(colors.size) { index -> colors[index].value() }
    }
}
