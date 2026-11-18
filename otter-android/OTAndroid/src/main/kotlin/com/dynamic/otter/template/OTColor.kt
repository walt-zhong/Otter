package com.dynamic.otter.template

import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import com.dynamic.otter.render.view.drawable.ColorGradientDrawable

class OTColor private constructor(private val value: Any) {

    fun value(): Int {
        return value as Int
    }

    fun createBackgroundColorDrawable(): ColorGradientDrawable {
        val color = value()
        return ColorGradientDrawable(
            GradientDrawable.Orientation.LEFT_RIGHT, intArrayOf(color, color)
        )
    }

    companion object {
        fun create(targetColor: String): OTColor? {
            var color = targetColor.trim()
            if (color.contains("%")) {
                val list = color.split(" ")
                if (list.size == 2) {
                    color = list[0]
                }
            }
            parseHexColor(color)?.let { return OTColor(it) }
            parseRGBAColor(color)?.let { return OTColor(it) }
            parseRGBColor(color)?.let { return OTColor(it) }
            parseSimpleColor(color)?.let { return OTColor(it) }
            return null
        }

        private fun parseHexColor(color: String): Int? {
            if (!color.startsWith("#")) {
                return null
            }
            val body = when (color.length) {
                4 -> color.drop(1).map { "$it$it" }.joinToString("")
                7, 9 -> color.drop(1)
                else -> return null
            }
            if (body.any { it !in '0'..'9' && it !in 'a'..'f' && it !in 'A'..'F' }) {
                return null
            }
            // #AARRGGBB，和 Color.parseColor、iOS、Web 一样，透明度在前。
            return runCatching { Color.parseColor("#$body") }.getOrNull()
        }

        private fun parseRGBColor(color: String): Int? {
            if (color.startsWith("rgb(") && color.endsWith(")")) {
                val colors = color.substring("rgb(".length, color.lastIndexOf(")")).split(",")
                return Color.rgb(
                    colors[0].trim().toInt(), colors[1].trim().toInt(), colors[2].trim().toInt()
                )
            }
            return null
        }

        private fun parseRGBAColor(color: String): Int? {
            if (color.startsWith("rgba(") && color.endsWith(")")) {
                val colors = color.substring("rgba(".length, color.lastIndexOf(")")).split(",")
                return Color.argb(
                    (colors[3].trim().toFloat() * 255).toInt(),
                    colors[0].trim().toInt(),
                    colors[1].trim().toInt(),
                    colors[2].trim().toInt()
                )
            }
            return null
        }

        private fun parseSimpleColor(color: String): Int? = when {
            color.equals("BLACK", true) -> Color.BLACK
            color.equals("DKGRAY", true) -> Color.DKGRAY
            color.equals("GRAY", true) -> Color.GRAY
            color.equals("LTGRAY", true) -> Color.LTGRAY
            color.equals("WHITE", true) -> Color.WHITE
            color.equals("RED", true) -> Color.RED
            color.equals("GREEN", true) -> Color.GREEN
            color.equals("BLUE", true) -> Color.BLUE
            color.equals("YELLOW", true) -> Color.YELLOW
            color.equals("CYAN", true) -> Color.CYAN
            color.equals("MAGENTA", true) -> Color.MAGENTA
            color.equals("TRANSPARENT", true) -> Color.TRANSPARENT
            else -> null
        }
    }
}