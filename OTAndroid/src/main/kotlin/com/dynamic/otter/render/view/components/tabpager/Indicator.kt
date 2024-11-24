package com.dynamic.otter.render.view.components.tabpager

import android.graphics.Paint
import android.graphics.Paint.Style
import android.view.View

class Indicator(private val indicatorView: View?) {
    private val indicatorPaint: Paint = Paint().apply {
        isAntiAlias = true
    }

    private var indicatorHeight: Int = 0
    private var indicatorSelectedWidth: Int = 0
    private var indicatorWidth: Int = 0
    private var indicatorMaxWidth: Int = 0
    private var progress = 0

    private var mIsMaxWith = false
    private var mIsMaxHeight = false


    fun setPaintStyle(style: Style): Indicator {
        indicatorPaint.style = style
        return this
    }

    fun setPaintStrokeWidth(strokeWidth: Float): Indicator {
        indicatorPaint.strokeWidth = strokeWidth
        return this
    }

    fun setIsMaxWith(isMaxWidth: Boolean): Indicator {
        this.mIsMaxWith = isMaxWidth
        return this
    }

    fun isMaxWidth(): Boolean {
        return mIsMaxWith
    }

    fun setIsMaxHeight(isMaxHeight: Boolean): Indicator {
        this.mIsMaxHeight = isMaxHeight
        return this
    }

    fun isMaxHeight(): Boolean {
        return mIsMaxHeight
    }

    fun setProgress(progress: Int): Indicator {
        this.progress = progress
        indicatorView?.invalidate()
        return this
    }

    fun getProgress(): Int {
        return progress
    }

    /**
     * 设置Indicator的最大长度
     */
    fun setIndicatorMaxWidth(indicatorMaxWidth: Int): Indicator {
        this.indicatorMaxWidth = indicatorMaxWidth
        return this
    }

    fun getIndicatorMaxWidth(): Int {
        return indicatorMaxWidth
    }

    /**
     * 设置Indicator 高度
     */
    fun setIndicatorHeight(indicatorHeight: Int): Indicator {
        this.indicatorHeight = indicatorHeight
        return this
    }

    fun getIndicatorHeight(): Int {
        return indicatorHeight
    }

    /**
     * 设置indicator选中时的长度
     */
    fun setIndicatorSelectedWidth(indicatorSelectedWidth: Int): Indicator {
        this.indicatorSelectedWidth = indicatorSelectedWidth
        return this
    }

    fun getIndicatorSelectedWidth(): Int {
        return indicatorSelectedWidth
    }

    fun setIndicatorWidth(indicatorWidth: Int): Indicator {
        this.indicatorWidth = if (mIsMaxWith) {
            indicatorWidth
        } else {
            this.indicatorMaxWidth.coerceAtMost(indicatorWidth)
        }

        return this

    }

    fun getIndicatorWidth(): Int {
        return indicatorWidth
    }

    /**
     * 设置indicator的颜色
     */
    fun setIndicatorColor(indicatorColor: Int): Indicator {
        indicatorPaint.setColor(indicatorColor)
        return this
    }

    fun getIndicatorPaint(): Paint {
        return indicatorPaint
    }

    fun invalidate(): Indicator {
        indicatorView?.invalidate()
        return this
    }
}