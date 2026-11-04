package com.dynamic.otter.render.view.basic

import android.content.Context
import android.graphics.Canvas
import android.graphics.Path
import android.graphics.RectF
import android.graphics.drawable.GradientDrawable
import android.util.AttributeSet
import android.view.View
import android.view.ViewGroup
import androidx.annotation.Keep
import com.dynamic.otter.render.view.applyUniformCornerOutline
import com.dynamic.otter.render.view.basic.capability.ICornerRoundConfigCapability
import kotlin.math.max

@Keep
open class OTAbsoluteLayout : ViewGroup, ICornerRoundConfigCapability {
    private var radius: FloatArray? = null
    private var roundCornerPath: Path? = null
    private var clipRadiiToSize = false

    constructor(context: Context) : super(context)

    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs)

    constructor(context: Context, attrs: AttributeSet?, defStyleAttr: Int) : super(
        context, attrs, defStyleAttr
    )

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val count = childCount

        var maxHeight = 0
        var maxWidth = 0

        // Find out how big everyone wants to be
        measureChildren(widthMeasureSpec, heightMeasureSpec)

        // Find rightmost and bottom-most child
        for (i in 0 until count) {
            val child = getChildAt(i)
            if (child.visibility != GONE) {
                var childRight: Int
                var childBottom: Int

                val lp = child.layoutParams as OTLayoutParams

                childRight = lp.x + child.measuredWidth
                childBottom = lp.y + child.measuredHeight

                maxWidth = max(maxWidth, childRight)
                maxHeight = max(maxHeight, childBottom)
            }
        }

        // Account for padding too
        maxWidth += paddingLeft + paddingRight
        maxHeight += paddingTop + paddingBottom

        // Check against minimum height and width
        maxHeight = max(maxHeight, suggestedMinimumHeight)
        maxWidth = max(maxWidth, suggestedMinimumWidth)

        setMeasuredDimension(
            resolveSizeAndState(maxWidth, widthMeasureSpec, 0),
            resolveSizeAndState(maxHeight, heightMeasureSpec, 0)
        )
    }

    override fun onLayout(
        changed: Boolean, l: Int, t: Int,
        r: Int, b: Int
    ) {
        val count = childCount

        for (i in 0 until count) {
            val child = getChildAt(i)
            if (child.visibility != GONE) {
                val lp =
                    child.layoutParams as OTLayoutParams

                val childLeft: Int = paddingLeft + lp.x
                val childTop: Int = paddingTop + lp.y
                child.layout(
                    childLeft, childTop,
                    childLeft + child.measuredWidth,
                    childTop + child.measuredHeight
                )
            }
        }
    }

    override fun generateDefaultLayoutParams(): LayoutParams {
        return OTLayoutParams(
            LayoutParams.WRAP_CONTENT,
            LayoutParams.WRAP_CONTENT,
            0,
            0
        )
    }

    override fun generateLayoutParams(p: LayoutParams?): LayoutParams {
        return OTLayoutParams(p)
    }

    override fun generateLayoutParams(attrs: AttributeSet?): LayoutParams {
        return OTLayoutParams(context, attrs)
    }

    override fun checkLayoutParams(p: LayoutParams?): Boolean {
        return p is OTLayoutParams
    }

    override fun shouldDelayChildPressedState(): Boolean {
        return false
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        if (clipRadiiToSize) {
            rebuildSizedCornerPath()
        }
    }

    internal fun clipContentToRadii(radii: FloatArray) {
        radius = radii.copyOf()
        clipRadiiToSize = true
        clipToOutline = false
        rebuildSizedCornerPath()
    }

    internal fun clearSizedCornerClip() {
        if (!clipRadiiToSize) {
            return
        }
        clipRadiiToSize = false
        roundCornerPath = null
    }

    private fun rebuildSizedCornerPath() {
        val radii = radius ?: return
        if (width <= 0 || height <= 0 || radii.size != 8) {
            return
        }
        val path = roundCornerPath ?: Path().also { roundCornerPath = it }
        path.reset()
        path.addRoundRect(
            RectF(0f, 0f, width.toFloat(), height.toFloat()),
            radii,
            Path.Direction.CW
        )
    }

    override fun dispatchDraw(canvas: Canvas) {
        val path = roundCornerPath
        if (path == null || clipToOutline) {
            super.dispatchDraw(canvas)
            return
        }
        canvas.save()
        canvas.clipPath(path)
        super.dispatchDraw(canvas)
        canvas.restore()
    }

    override fun configureViewRoundCorner(radius: FloatArray) {
        this.radius = radius
        if (radius.size != 8) {
            return
        }
        val uniform = radius[0]
        val sameCorner = radius[2] == uniform && radius[4] == uniform && radius[6] == uniform
        if (sameCorner && uniform > 0) {
            roundCornerPath = null
            applyUniformCornerOutline(uniform)
            return
        }
        clipToOutline = false
        outlineProvider = null
        val path = roundCornerPath ?: Path().also { roundCornerPath = it }
        path.reset()
        path.addRoundRect(
            RectF(0f, 0f, layoutParams.width.toFloat(), layoutParams.height.toFloat()),
            radius,
            Path.Direction.CW
        )
    }

    override fun configureViewRoundCornerBorder(
        borderColor: Int,
        borderWidth: Float,
        radius: FloatArray
    ) {
        if (background == null) {
            val target = GradientDrawable()
            target.shape = GradientDrawable.RECTANGLE
            target.cornerRadii = radius
            target.setStroke(borderWidth.toInt(), borderColor)
            background = target
        } else if (background is GradientDrawable) {
            val target = background as GradientDrawable
            target.cornerRadii = radius
            target.setStroke(borderWidth.toInt(), borderColor)
        }
    }
}