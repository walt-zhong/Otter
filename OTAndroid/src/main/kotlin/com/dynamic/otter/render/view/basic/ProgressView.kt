package com.dynamic.otter.render.view.basic

import android.animation.Animator
import android.animation.PropertyValuesHolder
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.CornerPathEffect
import android.graphics.Paint
import android.graphics.Path
import android.util.AttributeSet
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

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)

        mPaint.pathEffect = CornerPathEffect((h - PADDING * 2) / 2)
        mProgressBgPath.reset()
        mProgressBgPath.moveTo(PADDING, PADDING)
        mProgressBgPath.lineTo(w - PADDING, PADDING)
        mProgressBgPath.lineTo(w - PADDING, h - PADDING)
        mProgressBgPath.lineTo(PADDING, h - PADDING)
        mProgressBgPath.close()

        updateProgressPath()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        mPaint.color = mStrokeColor
        canvas.drawPath(mProgressBgPath, mPaint)
        mPaint.color = mTailColor
        canvas.drawPath(progressPath, mPaint)
    }

    private fun updateProgressPath(animateEnable: Boolean = false) {
        val startProgress = startProgressPercent * (measuredWidth - PADDING * 2)
        val progressWidth = (measuredWidth - PADDING * 2) * endProgressPercent

        if (!animateEnable) {
            progressPath.reset()
            progressPath.moveTo(startProgress, PADDING)
            progressPath.lineTo(startProgress + progressWidth, PADDING)
            progressPath.lineTo(startProgress + progressWidth, measuredHeight - PADDING)
            progressPath.lineTo(startProgress, measuredHeight - PADDING)
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

                    progressPath.moveTo(startProgress, PADDING)
                    progressPath.lineTo(startProgress + width, PADDING)
                    progressPath.lineTo(startProgress + width, measuredHeight - PADDING)
                    progressPath.lineTo(startProgress, measuredHeight - PADDING)
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
        updateProgressPath(bind.attr.animateEnable)
        invalidate()
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
        mTailColor = resolveColor(attr.trailColor, attrData, Color.GREEN)
    }

    private fun resolveColor(raw: String, attrData: Any?, fallback: Int): Int {
        val value = if (raw.isExp() && attrData is JSONObject) {
            raw.extractExpValue(attrData)
        } else {
            raw
        }
        return OTColor.create(value)?.value() ?: fallback
    }
}
