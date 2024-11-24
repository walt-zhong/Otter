package com.dynamic.otter.template

import android.graphics.Shader
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import app.visly.stretch.Rect
import com.dynamic.otter.render.view.attr.ViewAttr

class StyleConverter {
    companion object {
        val instance by lazy {
            StyleConverter()
        }
    }

    fun createLinearGradient(
        width: Float, height: Float, direction: GradientDrawable.Orientation, colors: IntArray
    ): Shader? = when (direction) {
        // draw the gradient from the top to the bottom
        GradientDrawable.Orientation.TOP_BOTTOM -> OTLinearColorGradient(
            0F, 0F, 0F, height, colors, null, Shader.TileMode.CLAMP
        )
        // raw the gradient from the bottom-left to the top-right
        GradientDrawable.Orientation.BOTTOM_TOP -> OTLinearColorGradient(
            0F, height, 0F, 0F, colors, null, Shader.TileMode.CLAMP
        )
        // draw the gradient from the left to the right
        GradientDrawable.Orientation.LEFT_RIGHT -> OTLinearColorGradient(
            0F, 0F, width, 0F, colors, null, Shader.TileMode.CLAMP
        )
        // draw the gradient from the right to the left
        GradientDrawable.Orientation.RIGHT_LEFT -> OTLinearColorGradient(
            width, 0F, 0F, 0F, colors, null, Shader.TileMode.CLAMP
        )
        // draw the gradient from the top-left to the bottom-right
        GradientDrawable.Orientation.TL_BR -> OTLinearColorGradient(
            0F, 0F, width, height, colors, null, Shader.TileMode.CLAMP
        )
        // draw the gradient from the top-right to the bottom-left
        GradientDrawable.Orientation.TR_BL -> OTLinearColorGradient(
            width, 0F, 0F, height, colors, null, Shader.TileMode.CLAMP
        )
        // draw the gradient from the bottom-right to the top-left
        GradientDrawable.Orientation.BR_TL -> OTLinearColorGradient(
            width, height, 0F, 0F, colors, null, Shader.TileMode.CLAMP
        )
        // draw the gradient from the bottom-left to the top-right
        GradientDrawable.Orientation.BL_TR -> OTLinearColorGradient(
            0F, height, width, 0F, colors, null, Shader.TileMode.CLAMP
        )

        else -> null
    }

    fun backgroundLinearColor(target: String?): OTLinearColor? {
        if (target != null) {
            if (target.startsWith("linear-gradient")) {
                val linear = getLinearGradient(target)
                val colors = getLinearGradientColors(linear)
                val direction = getDirection(linear)
                return OTLinearColor(direction, colors)
            } else {
                OTColor.create(target)?.let {
                    val colors = mutableListOf<OTColor>()
                    colors.add(it)
                    return OTLinearColor(GradientDrawable.Orientation.LEFT_RIGHT, colors)
                }
            }
        }
        return null
    }

    fun backgroundColor(target: String?): OTColor? {
        if (target == null) {
            return null
        }

        return target.let { OTColor.create(it) }
    }

    fun borderRadius(viewAttr: ViewAttr): OTRoundCorner? {
        var result: OTRoundCorner? = null
        viewAttr.radius?.let {
            val radius = OTSize.create(it)
            result = OTRoundCorner(
                leftTopRadius = radius,
                rightTopRadius = radius,
                leftBottomRadius = radius,
                rightBottomRadius = radius
            )
        }

        viewAttr.leftTopRadius?.let {
            if (result == null) {
                result = OTRoundCorner(
                    leftTopRadius = null,
                    rightTopRadius = null,
                    leftBottomRadius = null,
                    rightBottomRadius = null
                )
            }
            result?.leftTopRadius = OTSize.create(it)
        }

        viewAttr.rightTopRadius?.let {
            if (result == null) {
                result = OTRoundCorner(
                    leftTopRadius = null,
                    rightTopRadius = null,
                    leftBottomRadius = null,
                    rightBottomRadius = null
                )
            }
            result?.rightTopRadius = OTSize.create(it)
        }

        viewAttr.leftBottomRadius?.let {
            if (result == null) {
                result = OTRoundCorner(
                    leftTopRadius = null,
                    rightTopRadius = null,
                    leftBottomRadius = null,
                    rightBottomRadius = null
                )
            }
            result?.leftBottomRadius = OTSize.create(it)
        }

        viewAttr.rightBottomRadius?.let {
            if (result == null) {
                result = OTRoundCorner(
                    leftTopRadius = null,
                    rightTopRadius = null,
                    leftBottomRadius = null,
                    rightBottomRadius = null
                )
            }
            result?.rightBottomRadius = OTSize.create(it)
        }

        return result
    }

    fun textAlign(target: String): Int? = when (target) {
        "start" -> Gravity.LEFT
        "end" -> Gravity.RIGHT
        "center" -> Gravity.CENTER
        else -> null
    }

    fun padding(viewAttr: ViewAttr?): Rect<OTSize?>? {
        var result: Rect<OTSize?>? = null

        viewAttr?.padding?.let {
            val size = OTSize.create(it)
            result = Rect(size, size, size, size)
        }

        viewAttr?.paddingStart?.let {
            if (result == null) {
                result =
                    Rect(OTSize.Undefined, OTSize.Undefined, OTSize.Undefined, OTSize.Undefined)
            }

            result?.start = OTSize.create(it)
        }

        viewAttr?.paddingEnd?.let {
            if (result == null) {
                result =
                    Rect(OTSize.Undefined, OTSize.Undefined, OTSize.Undefined, OTSize.Undefined)
            }

            result?.end = OTSize.create(it)
        }

        viewAttr?.paddingTop?.let {
            if (result == null) {
                result =
                    Rect(OTSize.Undefined, OTSize.Undefined, OTSize.Undefined, OTSize.Undefined)
            }

            result?.top = OTSize.create(it)
        }

        viewAttr?.paddingBottom?.let {
            if (result == null) {
                result =
                    Rect(OTSize.Undefined, OTSize.Undefined, OTSize.Undefined, OTSize.Undefined)
            }

            result?.bottom = OTSize.create(it)
        }

        return result
    }

    private fun getLinearGradient(linear: String): List<String> {
        val result = mutableListOf<String>()
        try {
            val substring = linear.substring(linear.indexOf("(") + 1, linear.lastIndexOf(")"))
            when {
                substring.contains("rgba") -> {
                    substring.split("rgba").forEachIndexed { index, s ->
                        var content = s.trim()
                        if (content.endsWith(",")) {
                            content = content.substring(0, content.length - 1)
                        }
                        if (index > 0) {
                            result.add("rgba$content")
                        } else {
                            result.add(content)
                        }
                    }
                }

                substring.contains("rgb") -> {
                    substring.split("rgb").forEachIndexed { index, s ->
                        var content = s.trim()
                        if (content.endsWith(",")) {
                            content = content.substring(0, content.length - 1)
                        }
                        if (index > 0) {
                            result.add("rgb$content")
                        } else {
                            result.add(content)
                        }
                    }
                }

                else -> {
                    substring.split(",").forEach {
                        result.add(it.trim())
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return result
    }

    private fun getLinearGradientColors(linear: List<String>): MutableList<OTColor> {
        val colors = mutableListOf<String>()
        linear.forEach {
            if (!it.startsWith("to")) {
                colors.add(it)
            }
        }
        val intColors = mutableListOf<OTColor>()
        colors.forEach { color ->
            intColors.add(
                OTColor.create(color)
                    ?: throw IllegalArgumentException("linearColor create color error")
            )
        }
        return intColors
    }

    private fun getDirection(linear: List<String>): GradientDrawable.Orientation {
        if (linear.isNotEmpty()) {
            return when (linear[0]) {
                "to right" -> GradientDrawable.Orientation.LEFT_RIGHT
                "toright" -> GradientDrawable.Orientation.LEFT_RIGHT

                "to left" -> GradientDrawable.Orientation.RIGHT_LEFT
                "toleft" -> GradientDrawable.Orientation.RIGHT_LEFT

                "totop" -> GradientDrawable.Orientation.BOTTOM_TOP
                "to top" -> GradientDrawable.Orientation.BOTTOM_TOP

                "tobottom" -> GradientDrawable.Orientation.TOP_BOTTOM
                "to bottom" -> GradientDrawable.Orientation.TOP_BOTTOM

                "totopleft" -> GradientDrawable.Orientation.BR_TL
                "to top left" -> GradientDrawable.Orientation.BR_TL

                "totopright" -> GradientDrawable.Orientation.BL_TR
                "to top right" -> GradientDrawable.Orientation.BL_TR

                "tobottomleft" -> GradientDrawable.Orientation.TR_BL
                "to bottom left" -> GradientDrawable.Orientation.TR_BL

                "tobottomright" -> GradientDrawable.Orientation.TL_BR
                "to bottom right" -> GradientDrawable.Orientation.TL_BR
                else -> GradientDrawable.Orientation.TOP_BOTTOM
            }
        }
        return GradientDrawable.Orientation.TOP_BOTTOM
    }
}