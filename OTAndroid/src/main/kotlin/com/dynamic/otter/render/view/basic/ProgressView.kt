package com.dynamic.otter.render.view.basic

import android.animation.Animator
import android.animation.PropertyValuesHolder
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.CornerPathEffect
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Shader
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import android.view.animation.AccelerateDecelerateInterpolator
import androidx.annotation.Keep
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.render.utils.FunctionExt.isExp
import com.dynamic.otter.render.view.attr.ProgressAttr
import com.dynamic.otter.render.view.attr.ViewAttr
import com.dynamic.otter.render.view.basic.capability.IDataBindingCapability
import com.dynamic.otter.render.view.basic.capability.IStyleBindingCapability
import com.dynamic.otter.template.OTColor
import com.dynamic.otter.template.OTLinearColor
import com.dynamic.otter.template.StyleConverter

@Keep
class ProgressView : View, IDataBindingCapability,IStyleBindingCapability {

    companion object {
        private const val PROGRESS_WIDTH_VALUE_HOLDER = "PROGRESS_WIDTH_VALUE_HOLDER"
        private const val PADDING = 1.0f
    }

    private var currentProgressWidth: Float = 0f

    private val mPaint = Paint()
    private val mProgressBgPath = Path()
    private val progressPath = Path()

    private var animator: Animator? = null
    private var mStrokeColor = Color.GRAY
    private var mTailColor = Color.GREEN
    private var barGradient: OTLinearColor? = null

    var seekable: Boolean = false
        set(value) {
            field = value
            isClickable = value
        }

    var onSeekChanged: ((fraction: Float, settled: Boolean) -> Unit)? = null

    private var startProgressPercent = 0f
        get() = field.coerceIn(0f, 1f)
    private var endProgressPercent = 1f
        get() = field.coerceAtMost(1f)

    constructor(context: Context) : super(context) {
        initView()
    }

    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs) {
        initView()
    }

    private fun initView() {
        mPaint.strokeJoin = Paint.Join.ROUND
        mPaint.strokeCap = Paint.Cap.ROUND
        mPaint.isAntiAlias = true
        mPaint.strokeWidth = 1f
    }

    fun setFraction(fraction: Float) {
        animator?.cancel()
        startProgressPercent = 0f
        endProgressPercent = fraction.coerceIn(0f, 1f)
        invalidate()
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (!seekable) {
            return super.onTouchEvent(event)
        }
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                parent?.requestDisallowInterceptTouchEvent(true)
                val fraction = fractionAt(event.x)
                setFraction(fraction)
                onSeekChanged?.invoke(fraction, false)
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                val fraction = fractionAt(event.x)
                setFraction(fraction)
                onSeekChanged?.invoke(fraction, true)
                return true
            }
        }
        return true
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        val (top, thick) = band(h.toFloat())
        mPaint.pathEffect = CornerPathEffect(thick / 2f)
        mProgressBgPath.reset()
        mProgressBgPath.moveTo(PADDING, top)
        mProgressBgPath.lineTo(w - PADDING, top)
        mProgressBgPath.lineTo(w - PADDING, top + thick)
        mProgressBgPath.lineTo(PADDING, top + thick)
        mProgressBgPath.close()

        updateProgressPath(viewWidth = w.toFloat(), viewHeight = h.toFloat())
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (width > 0 && height > 0 && animator?.isRunning != true) {
            updateProgressPath(viewWidth = width.toFloat(), viewHeight = height.toFloat())
        }

        mPaint.shader = null
        mPaint.color = mStrokeColor
        canvas.drawPath(mProgressBgPath, mPaint)
        val gradient = barGradient
        if (gradient != null && measuredWidth > 0) {
            val colors = IntArray(gradient.colors.size) { gradient.colors[it].value() }
            val inner = measuredWidth - PADDING * 2
            val start = startProgressPercent * inner
            val end = start + currentProgressWidth.coerceAtLeast(1f)
            mPaint.shader = LinearGradient(
                start,
                PADDING,
                end,
                PADDING,
                colors,
                null,
                Shader.TileMode.CLAMP
            )
        } else {
            mPaint.color = mTailColor
        }
        canvas.drawPath(progressPath, mPaint)
        mPaint.shader = null
    }

    private fun updateProgressPath(
        animateEnable: Boolean = false,
        viewWidth: Float = width.toFloat(),
        viewHeight: Float = height.toFloat()
    ) {
        val inner = (viewWidth - PADDING * 2).coerceAtLeast(0f)
        val (top, thick) = band(viewHeight)
        val startProgress = startProgressPercent * inner
        val progressWidth = inner * endProgressPercent

        if (!animateEnable) {
            progressPath.reset()
            progressPath.moveTo(startProgress, top)
            progressPath.lineTo(startProgress + progressWidth, top)
            progressPath.lineTo(startProgress + progressWidth, top + thick)
            progressPath.lineTo(startProgress, top + thick)
            progressPath.close()
        } else {
            animator?.cancel()
            animator = ValueAnimator().apply {
                setValues(
                    PropertyValuesHolder.ofFloat(
                        PROGRESS_WIDTH_VALUE_HOLDER, currentProgressWidth, progressWidth
                    )
                )
                duration = 300
                interpolator = AccelerateDecelerateInterpolator()

                addUpdateListener {
                    val width = it.getAnimatedValue(PROGRESS_WIDTH_VALUE_HOLDER) as Float
                    progressPath.reset()

                    progressPath.moveTo(startProgress, top)
                    progressPath.lineTo(startProgress + width, top)
                    progressPath.lineTo(startProgress + width, top + thick)
                    progressPath.lineTo(startProgress, top + thick)
                    progressPath.close()

                    invalidate()
                }
                start()
            }
        }
        currentProgressWidth = progressWidth
    }

    override fun onBindData(data: Any?) {
        val bind = data as? ProgressBind ?: return
        val valueMin = bind.attr.valueMin.resolve(bind.itemData)
        val valueMax = bind.attr.valueMax.resolve(bind.itemData)
        startProgressPercent = valueMin
        endProgressPercent = valueMax - valueMin
        if (width > 0 && height > 0) {
            updateProgressPath(bind.attr.animateEnable)
        }
        invalidate()
    }

    private fun band(viewHeight: Float): Pair<Float, Float> {
        val full = (viewHeight - PADDING * 2).coerceAtLeast(0f)
        val slim = 6f * resources.displayMetrics.density
        val thick = if (full > slim * 2.2f) slim else full
        val top = ((viewHeight - thick) / 2f).coerceAtLeast(0f)
        return top to thick
    }

    private fun fractionAt(x: Float): Float {
        val inner = (width - PADDING * 2).coerceAtLeast(1f)
        return ((x - PADDING) / inner).coerceIn(0f, 1f)
    }

    private fun String.resolve(itemData: JSONObject?): Float {
        val raw = if (itemData != null) extractExpValue(itemData) else this
        return raw.toFloat()
    }

    class ProgressBind(
        val attr: ProgressAttr,
        val itemData: JSONObject?
    )

    override fun onBindStyle(attr: ViewAttr, attrData: Any?) {
        if (attr !is ProgressAttr) {
            return
        }
        mStrokeColor = resolveColor(attr.strokeColor, attrData, Color.GRAY)
        val trail = resolveRaw(attr.trailColor, attrData)
        val gradient = if (trail.startsWith("linear-gradient")) {
            runCatching { StyleConverter.backgroundLinearColor(trail) }.getOrNull()
        } else {
            null
        }
        if (gradient != null && gradient.colors.size > 1) {
            barGradient = gradient
            mTailColor = gradient.colors.last().value()
        } else {
            barGradient = null
            mTailColor = OTColor.create(trail)?.value() ?: Color.GREEN
        }
        invalidate()
    }

    private fun resolveColor(raw: String, attrData: Any?, fallback: Int): Int {
        return OTColor.create(resolveRaw(raw, attrData))?.value() ?: fallback
    }

    private fun resolveRaw(raw: String, attrData: Any?): String {
        return if (raw.isExp() && attrData is JSONObject) {
            raw.extractExpValue(attrData)
        } else {
            raw
        }
    }
}
