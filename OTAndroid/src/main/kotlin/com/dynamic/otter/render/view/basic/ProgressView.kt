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
import com.dynamic.otter.data.TemplateKey
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

    private var percent: Float = 1f
        get() {
            return if (field < 0) {
                0f
            } else field.coerceAtMost(1f)
        }
    private var currentProgressWidth: Float = 0f

    private val mPaint = Paint()
    private val mProgressBgPath = Path()
    private val progressPath = Path()

    private var animator: Animator? = null
    private var mStrokeColor = Color.GRAY
    private var mTailColor = Color.GREEN

    private var startProgressPercent = 0f
        get() {
            return if (field < 0f) {
                0f
            } else field.coerceAtMost(1f)
        }
    private var endProgressPercent = 1f
        get() {
            return if (field > 1f) {
                1f
            } else field.coerceAtMost(1f)
        }

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

        if (percent > 0) {
            mPaint.color = mTailColor
            canvas.drawPath(progressPath, mPaint)
        }
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
        if (data is JSONObject) {
            val valueMin = data[TemplateKey.ATTR_VALUE_MIN] as Float
            val valueMax = data[TemplateKey.ATTR_VALUE_MAX] as Float
            startProgressPercent = valueMin
            endProgressPercent = (valueMax - valueMin)
            val animateEnable = data[TemplateKey.ATTR_ANIMATE_ENABLE] as Boolean
            updateProgressPath(animateEnable)
            invalidate()
        }
    }

    override fun onBindStyle(attr: ViewAttr,attrData:Any?) {
        if (attr is ProgressAttr) {
            val strokeColor = attr.strokeColor
            val trailColor = attr.trailColor

            mStrokeColor = if(strokeColor.isExp() && attrData is JSONObject){
                OTColor.create(attr.strokeColor.extractExpValue(attrData))?.value() ?: Color.GRAY
            }else{
                OTColor.create(attr.strokeColor)?.value() ?: Color.GRAY
            }

            mTailColor = if(trailColor.isExp() && attrData is JSONObject){
                OTColor.create(attr.trailColor.extractExpValue(attrData))?.value() ?: Color.GREEN
            }else{
                OTColor.create(attr.trailColor)?.value() ?: Color.GREEN
            }
        }
    }
}
