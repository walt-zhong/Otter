package com.dynamic.otter.render.view.components.tabpager

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View
import androidx.annotation.Keep
import com.dynamic.otter.utils.ScreenUtils

@Keep
class IndicatorLineView : View, IViewIndicator {
    private var height: Int = 0
    private var indicatorRadius = 0
    private lateinit var indicator: Indicator
    private var indicatorStyle: Int = 0

    constructor(context: Context) : super(context) {
        init(context)
    }

    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs) {
        init(context)
    }

    constructor(context: Context, attrs: AttributeSet?, defStyle: Int) : super(
        context,
        attrs,
        defStyle
    ) {
        init(context)
    }


    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        height = getHeight()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        var top = indicator.getIndicatorPaint().strokeWidth*0.5f
        if (indicatorStyle == 0) {
            val temA = (height - indicator.getIndicatorHeight().toFloat())
            val temB = indicator.getIndicatorPaint().strokeWidth*0.5f
            top = temA - temB
        } else if (indicatorStyle == 1) {
            top = height - (indicator.getIndicatorHeight()*0.5f)
        }
        val left = indicator.getProgress()
        val right = (indicator.getProgress()) + indicator.getIndicatorWidth()
        val bottom = top.toInt() + indicator.getIndicatorHeight()

        indicator.let {
            canvas.drawRoundRect(
                left.toFloat(),
                top,
                right.toFloat(),
                bottom.toFloat(),
                indicatorRadius.toFloat(),
                indicatorRadius.toFloat(),
                it.getIndicatorPaint()
            )
        }
    }

    private fun init(context: Context) {
        indicator = Indicator(this)
        indicator?.let {
            it.setIndicatorSelectedWidth(ScreenUtils.dpAdapt(context, 10f))
            it.setIndicatorMaxWidth(ScreenUtils.dpAdapt(context, 60f))
            it.setIndicatorHeight(ScreenUtils.dpAdapt(context, 3f))
            it.setIndicatorColor(Color.parseColor("#ffe4ff50"))
            it.setPaintStyle(Paint.Style.FILL)
            it.setPaintStrokeWidth(0f)
            it.setIsMaxWith(false)
            it.setIsMaxHeight(false)
            it.setIndicatorWidth(0)
        }

        setIndicatorRadius(ScreenUtils.dpAdapt(context, 2f))
    }

    fun setIndicatorRadius(radius: Int) {
        this.indicatorRadius = radius
    }

    fun getIndicatorRadius(): Int {
        return indicatorRadius
    }

    override fun <T : View> getView(): T {
        return this as T
    }

    override fun getIndicator(): Indicator? {
        return indicator
    }
}