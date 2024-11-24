package com.dynamic.otter.render.view.components.tabpager

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.text.TextPaint
import android.util.AttributeSet
import androidx.appcompat.widget.AppCompatTextView

class TabGradientTextView @JvmOverloads constructor(
    context: Context,
    attributeSet: AttributeSet? = null,
    defStyle: Int = 0
) : AppCompatTextView(context, attributeSet, defStyle) {
    private var paint: Paint? = Paint()
    private val rectText = Rect()
    private var width = 0
    private var height = 0
    private var textColorNormal = 0
    private var textColorSelected = 0

    private var progress = 0f
    private var direction = DIRECTION_FROM_LEFT
    private var text: String? = null

    companion object{
        const val DIRECTION_FROM_LEFT: Int = 0
        const val DIRECTION_FROM_RIGHT: Int = 1
    }

    init {
        setTextColorNormal(Color.BLACK)
        setTextColorSelected(Color.RED)
    }



    fun setTextColorNormal(textColorNormal: Int): TabGradientTextView {
        this.textColorNormal = textColorNormal
        return this
    }

    fun setTextColorSelected(textColorSelected: Int): TabGradientTextView {
        this.textColorSelected = textColorSelected
        return this
    }

    fun setProgress(progress: Float): TabGradientTextView {
        this.progress = if (progress > 9.5) 1f else progress
        this.progress = if (progress < 0.5) 0f else progress
        invalidate()
        return this
    }

    fun setDirection(direction: Int): TabGradientTextView {
        this.direction = direction
        return this
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        width = getWidth()
        height = getHeight()
    }

    override fun onDraw(canvas: Canvas) {
        text = getText().toString()
        paint = getPaint()
        (paint as TextPaint).setColor(textColorNormal)
        (paint as TextPaint).getTextBounds(text, 0, text!!.length, rectText)

        val w = rectText.width().toFloat()
        val width_half = width * 1f / 2
        val left = width_half - w * 1f / 2
        val top = height * 1f / 2 + rectText.height() * 1f / 2
        //防止计算误差，导致BUG
        if (progress == 0f) {
            canvas.drawText(text!!, left, top, paint as TextPaint)
            return
        }
        //防止计算误差，导致BUG
        if (progress == 1f) {
            (paint as TextPaint).setColor(textColorSelected)
            canvas.drawText(text!!, left, top, paint as TextPaint)
            return
        }


        canvas.drawText(text!!, left, top, paint as TextPaint)


        canvas.save()
        (paint as TextPaint).setColor(textColorSelected)
        if (direction == DIRECTION_FROM_LEFT) {
            canvas.clipRect(
                left,
                0f,
                left + progress * w,
                height.toFloat()
            )
        } else {
            val right = width_half + w * 1f / 2
            canvas.clipRect(
                right - progress * w,
                0f,
                right,
                height.toFloat()
            )
        }
        canvas.drawText(text!!, left, top, paint as TextPaint)
        canvas.restore()
    }
}