package com.dynamic.otter.render.view.basic

import android.content.Context
import android.graphics.Outline
import android.graphics.Path
import android.graphics.RectF
import android.graphics.drawable.GradientDrawable
import android.util.AttributeSet
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import androidx.annotation.Keep
import com.dynamic.otter.render.view.basic.capability.ICornerRoundConfigCapability
import kotlin.math.max

@Keep
open class OTAbsoluteLayout : ViewGroup, ICornerRoundConfigCapability {
    private var radius: FloatArray? = null
    private var roundCornerPath: Path? = null

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

                maxWidth = max(maxWidth.toDouble(), childRight.toDouble()).toInt()
                maxHeight = max(maxHeight.toDouble(), childBottom.toDouble()).toInt()
            }
        }

        // Account for padding too
        maxWidth += paddingLeft + paddingRight
        maxHeight += paddingTop + paddingBottom

        // Check against minimum height and width
        maxHeight = max(maxHeight.toDouble(), suggestedMinimumHeight.toDouble()).toInt()
        maxWidth = max(maxWidth.toDouble(), suggestedMinimumWidth.toDouble()).toInt()

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

    override fun configureViewRoundCorner(radius: FloatArray) {
        this.radius = radius
        if (radius.size == 8) {
            val lt = radius[0]
            val rt = radius[2]
            val lb = radius[4]
            val rb = radius[6]

            if (lt == rt && lb == rt && lb == rb && lt > 0) {// 四个角都需要设置相同大小的圆角
                roundCornerPath = null
                this.clipToOutline = true
                this.outlineProvider = object : ViewOutlineProvider() {
                    override fun getOutline(view: View, outline: Outline) {
                        if (alpha >= 0.0f) {
                            outline.alpha = alpha
                        }

                        outline.setRoundRect(0, 0, view.width, view.height, lt)
                    }
                }
            } else { // 四个角的圆角大小不一样的情况下。使用Path的方法绘制
                this.clipToOutline = false
                if (roundCornerPath == null) {
                    roundCornerPath = Path()
                } else {
                    roundCornerPath?.reset()
                }

                roundCornerPath?.addRoundRect(
                    RectF(
                        0f,
                        0f,
                        this.layoutParams.width.toFloat(),
                        this.layoutParams.height.toFloat(),
                    ), radius, Path.Direction.CW
                )

                this.outlineProvider = null
            }
        }
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