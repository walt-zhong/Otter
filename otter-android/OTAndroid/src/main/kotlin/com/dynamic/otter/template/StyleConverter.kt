package com.dynamic.otter.template

import android.graphics.Shader
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import app.visly.stretch.Rect
import com.dynamic.otter.render.view.attr.ViewAttr

object StyleConverter {
    fun createLinearGradient(
        width: Float,
        height: Float,
        direction: GradientDrawable.Orientation,
        colors: IntArray
    ): Shader? {
        val line = when (direction) {
            GradientDrawable.Orientation.TOP_BOTTOM -> floatArrayOf(0F, 0F, 0F, height)
            GradientDrawable.Orientation.BOTTOM_TOP -> floatArrayOf(0F, height, 0F, 0F)
            GradientDrawable.Orientation.LEFT_RIGHT -> floatArrayOf(0F, 0F, width, 0F)
            GradientDrawable.Orientation.RIGHT_LEFT -> floatArrayOf(width, 0F, 0F, 0F)
            GradientDrawable.Orientation.TL_BR -> floatArrayOf(0F, 0F, width, height)
            GradientDrawable.Orientation.TR_BL -> floatArrayOf(width, 0F, 0F, height)
            GradientDrawable.Orientation.BR_TL -> floatArrayOf(width, height, 0F, 0F)
            GradientDrawable.Orientation.BL_TR -> floatArrayOf(0F, height, width, 0F)
            else -> return null
        }
        return OTLinearColorGradient(
            line[0],
            line[1],
            line[2],
            line[3],
            colors,
            null,
            Shader.TileMode.CLAMP
        )
    }

    fun backgroundLinearColor(target: String?): OTLinearColor? {
        if (target.isNullOrBlank()) {
            return null
        }
        if (!target.startsWith("linear-gradient")) {
            val color = OTColor.create(target) ?: return null
            return OTLinearColor(GradientDrawable.Orientation.LEFT_RIGHT, mutableListOf(color))
        }
        val linear = getLinearGradient(target)
        return OTLinearColor(getDirection(linear), getLinearGradientColors(linear))
    }

    fun backgroundColor(target: String?): OTColor? {
        if (target == null) {
            return null
        }
        return OTColor.create(target)
    }

    fun borderRadius(viewAttr: ViewAttr): OTRoundCorner? {
        val uniform = viewAttr.radius?.let { OTSize.create(it) }
        val leftTop = viewAttr.leftTopRadius?.let { OTSize.create(it) }
        val rightTop = viewAttr.rightTopRadius?.let { OTSize.create(it) }
        val leftBottom = viewAttr.leftBottomRadius?.let { OTSize.create(it) }
        val rightBottom = viewAttr.rightBottomRadius?.let { OTSize.create(it) }
        if (uniform == null && leftTop == null && rightTop == null && leftBottom == null && rightBottom == null) {
            return null
        }
        return OTRoundCorner(
            leftTopRadius = leftTop ?: uniform,
            rightTopRadius = rightTop ?: uniform,
            leftBottomRadius = leftBottom ?: uniform,
            rightBottomRadius = rightBottom ?: uniform
        )
    }

    fun textAlign(target: String): Int? = when (target) {
        "start" -> Gravity.LEFT
        "end" -> Gravity.RIGHT
        "center" -> Gravity.CENTER
        else -> null
    }

    fun padding(viewAttr: ViewAttr?): Rect<OTSize?>? {
        if (viewAttr == null) {
            return null
        }
        val uniform = viewAttr.padding?.let { OTSize.create(it) }
        val start = viewAttr.paddingStart?.let { OTSize.create(it) }
        val end = viewAttr.paddingEnd?.let { OTSize.create(it) }
        val top = viewAttr.paddingTop?.let { OTSize.create(it) }
        val bottom = viewAttr.paddingBottom?.let { OTSize.create(it) }
        if (uniform == null && start == null && end == null && top == null && bottom == null) {
            return null
        }
        val fallback = uniform ?: OTSize.Undefined
        return Rect(
            start ?: fallback,
            end ?: fallback,
            top ?: fallback,
            bottom ?: fallback
        )
    }

    private fun getLinearGradient(linear: String): List<String> {
        val inner = try {
            linear.substring(linear.indexOf("(") + 1, linear.lastIndexOf(")"))
        } catch (_: Exception) {
            return emptyList()
        }
        return when {
            inner.contains("rgba") -> splitColorFunction(inner, "rgba")
            inner.contains("rgb") -> splitColorFunction(inner, "rgb")
            else -> inner.split(",").map { it.trim() }
        }
    }

    private fun splitColorFunction(source: String, functionName: String): List<String> {
        return source.split(functionName).mapIndexed { index, part ->
            val content = part.trim().removeSuffix(",").trim()
            if (index == 0) content else "$functionName$content"
        }
    }

    private fun getLinearGradientColors(linear: List<String>): MutableList<OTColor> {
        return linear
            .filterNot { it.startsWith("to") }
            .map { color ->
                OTColor.create(color)
                    ?: throw IllegalArgumentException("linearColor create color error")
            }
            .toMutableList()
    }

    private fun getDirection(linear: List<String>): GradientDrawable.Orientation {
        return when (linear.firstOrNull()?.replace(" ", "")) {
            "toright" -> GradientDrawable.Orientation.LEFT_RIGHT
            "toleft" -> GradientDrawable.Orientation.RIGHT_LEFT
            "totop" -> GradientDrawable.Orientation.BOTTOM_TOP
            "tobottom" -> GradientDrawable.Orientation.TOP_BOTTOM
            "totopleft" -> GradientDrawable.Orientation.BR_TL
            "totopright" -> GradientDrawable.Orientation.BL_TR
            "tobottomleft" -> GradientDrawable.Orientation.TR_BL
            "tobottomright" -> GradientDrawable.Orientation.TL_BR
            else -> GradientDrawable.Orientation.TOP_BOTTOM
        }
    }
}
