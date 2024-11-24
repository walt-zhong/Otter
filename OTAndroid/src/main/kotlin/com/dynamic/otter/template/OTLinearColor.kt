package com.dynamic.otter.template

import android.graphics.Shader
import android.graphics.drawable.GradientDrawable
import android.widget.TextView
import com.dynamic.otter.render.view.drawable.LinearColorGradientDrawable

/**
 * @suppress
 */
class OTLinearColor(
    val direction: GradientDrawable.Orientation,
    val colors: MutableList<OTColor>
) {

    fun createShader(view: TextView): Shader? {
        val height = view.layoutParams.height.toFloat()
        val width = view.layoutParams.width.toFloat()
        return createShader(view, width, height)
    }

    private fun createShader(
        view: TextView, width: Float, height: Float
    ) = if (colors.size == 1) {
        val value = colors[0].value()
        val result = IntArray(2)
        result[0] = value
        result[1] = value
        StyleConverter.instance.createLinearGradient(width, height, direction, result)
    } else {
        val result = IntArray(colors.size)
        colors.forEachIndexed { index, color ->
            result[index] = color.value()
        }
        StyleConverter.instance.createLinearGradient(width, height, direction, result)
    }


    fun createDrawable() = if (colors.size == 1) {
        val value = colors[0].value()
        val result = IntArray(2)
        result[0] = value
        result[1] = value
        LinearColorGradientDrawable(direction, result)
    } else {
        val result = IntArray(colors.size)
        colors.forEachIndexed { index, color ->
            result[index] = color.value()
        }
        LinearColorGradientDrawable(direction, result)
    }
}

