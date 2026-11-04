package com.dynamic.otter.render.view.drawable

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.drawable.Drawable
import kotlin.math.max
import kotlin.math.roundToInt

internal class CoverBitmapDrawable(private val bitmap: Bitmap) : Drawable() {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { isFilterBitmap = true }
    private val dest = RectF()

    override fun draw(canvas: Canvas) {
        val area = bounds
        if (area.width() <= 0 || area.height() <= 0 || bitmap.isRecycled) {
            return
        }
        val scale = max(
            area.width().toFloat() / bitmap.width,
            area.height().toFloat() / bitmap.height
        )
        val width = bitmap.width * scale
        val height = bitmap.height * scale
        val left = area.left + (area.width() - width) / 2f
        val top = area.top + (area.height() - height) / 2f
        dest.set(left, top, left + width, top + height)
        canvas.drawBitmap(bitmap, null, dest, paint)
    }

    override fun setAlpha(alpha: Int) {
        paint.alpha = alpha
    }

    override fun setColorFilter(colorFilter: ColorFilter?) {
        paint.colorFilter = colorFilter
    }

    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = PixelFormat.TRANSLUCENT
}

/**
 * 图片按视图宽度等比缩放，高出的部分可以上下拖。子节点不跟着动。
 */
internal class PanningBitmapDrawable(private val bitmap: Bitmap) : Drawable() {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { isFilterBitmap = true }
    private val dest = RectF()
    private var offset = 0f

    fun offsetPx(): Int = offset.roundToInt()

    fun panBy(dy: Float, viewHeight: Int): Boolean {
        return panTo(offset + dy, viewHeight)
    }

    fun panTo(target: Float, viewHeight: Int): Boolean {
        val max = maxOffset(viewHeight)
        val next = target.coerceIn(0f, max)
        if (next == offset) {
            return false
        }
        offset = next
        invalidateSelf()
        return true
    }

    fun maxOffset(viewHeight: Int): Float {
        val width = bounds.width()
        if (width <= 0 || bitmap.width <= 0) {
            return 0f
        }
        val fitted = width.toFloat() * bitmap.height / bitmap.width
        return (fitted - viewHeight).coerceAtLeast(0f)
    }

    override fun draw(canvas: Canvas) {
        val area = bounds
        if (area.width() <= 0 || bitmap.isRecycled || bitmap.width <= 0) {
            return
        }
        val height = area.width().toFloat() * bitmap.height / bitmap.width
        dest.set(
            area.left.toFloat(),
            area.top - offset,
            area.right.toFloat(),
            area.top - offset + height
        )
        val checkpoint = canvas.save()
        canvas.clipRect(area)
        canvas.drawBitmap(bitmap, null, dest, paint)
        canvas.restoreToCount(checkpoint)
    }

    override fun setAlpha(alpha: Int) {
        paint.alpha = alpha
    }

    override fun setColorFilter(colorFilter: ColorFilter?) {
        paint.colorFilter = colorFilter
    }

    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = PixelFormat.TRANSLUCENT
}
