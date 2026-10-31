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
        return createShader(
            view.layoutParams.width.toFloat(),
            view.layoutParams.height.toFloat()
        )
    }

    fun createShader(width: Float, height: Float): Shader? {
        if (width <= 0f || height <= 0f) {
            return null
        }
        return StyleConverter.createLinearGradient(width, height, direction, colorArray())
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
