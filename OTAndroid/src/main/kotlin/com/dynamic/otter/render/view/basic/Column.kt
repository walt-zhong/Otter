package com.dynamic.otter.render.view.basic

import android.content.Context
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.VelocityTracker
import android.view.View
import android.view.View.MeasureSpec
import android.view.ViewConfiguration
import android.view.ViewGroup
import android.view.ViewGroup.MarginLayoutParams
import android.widget.FrameLayout
import android.widget.OverScroller
import androidx.annotation.Keep
import androidx.core.widget.NestedScrollView
import com.dynamic.otter.render.view.attr.ColumnAttr
import com.dynamic.otter.render.view.attr.ViewAttr
import com.dynamic.otter.render.view.basic.capability.IStyleBindingCapability
import com.dynamic.otter.render.view.drawable.PanningBitmapDrawable
import kotlin.math.abs

@Keep
class Column : OTAbsoluteLayout, IStyleBindingCapability {
    var scrollContent: ViewGroup? = null
        private set

    private var installingScroll = false
    private val backdropPan = BackdropPanner(this)

    constructor(context: Context) : super(context)

    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs)

    constructor(context: Context, attrs: AttributeSet?, defStyleAttr: Int) : super(
        context, attrs, defStyleAttr
    )

    override fun setId(id: Int) {
        super.setId(id)
        if (ColumnAttr.isScrolling(id)) {
            ensureScrollContent()
        }
    }

    override fun onBindStyle(attr: ViewAttr, attrData: Any?) {
        if (attr is ColumnAttr && attr.scroll) {
            ensureScrollContent()
        }
    }

    override fun onInterceptTouchEvent(ev: MotionEvent): Boolean {
        if (backdropPan.onIntercept(ev)) {
            return true
        }
        return super.onInterceptTouchEvent(ev)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (backdropPan.onTouch(event)) {
            return true
        }
        return super.onTouchEvent(event)
    }

    override fun addView(child: View, index: Int, params: ViewGroup.LayoutParams) {
        val content = scrollContent
        if (!installingScroll && content != null) {
            content.addView(child, index, params)
            return
        }
        super.addView(child, index, params)
    }

    private fun ensureScrollContent() {
        if (scrollContent != null) {
            return
        }
        clipChildren = false
        val existing = ArrayList<View>(childCount)
        for (index in 0 until childCount) {
            existing.add(getChildAt(index))
        }
        installingScroll = true
        existing.forEach { removeView(it) }
        val content = OTAbsoluteLayout(context).apply {
            clipChildren = false
        }
        val scroller = UnspecifiedHeightScrollView(context)
        super.addView(
            scroller,
            OTLayoutParams(
                LayoutParams.MATCH_PARENT,
                LayoutParams.MATCH_PARENT,
                0,
                0
            )
        )
        scroller.addView(
            content,
            FrameLayout.LayoutParams(
                LayoutParams.MATCH_PARENT,
                LayoutParams.WRAP_CONTENT
            )
        )
        existing.forEach { child ->
            content.addView(child)
        }
        installingScroll = false
        scrollContent = content
    }

    private class UnspecifiedHeightScrollView(context: Context) : NestedScrollView(context) {
        init {
            isFillViewport = false
        }

        override fun measureChild(
            child: View,
            parentWidthMeasureSpec: Int,
            parentHeightMeasureSpec: Int
        ) {
            val childWidthMeasureSpec = getChildMeasureSpec(
                parentWidthMeasureSpec,
                paddingLeft + paddingRight,
                child.layoutParams.width
            )
            child.measure(
                childWidthMeasureSpec,
                MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
            )
        }

        override fun measureChildWithMargins(
            child: View,
            parentWidthMeasureSpec: Int,
            widthUsed: Int,
            parentHeightMeasureSpec: Int,
            heightUsed: Int
        ) {
            val lp = child.layoutParams as MarginLayoutParams
            val childWidthMeasureSpec = getChildMeasureSpec(
                parentWidthMeasureSpec,
                paddingLeft + paddingRight + lp.leftMargin + lp.rightMargin + widthUsed,
                lp.width
            )
            child.measure(
                childWidthMeasureSpec,
                MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
            )
        }
    }
}

/**
 * 上下拖动只移动列的背景图。点按仍然交给子节点。
 */
private class BackdropPanner(private val host: Column) {
    private val slop = ViewConfiguration.get(host.context).scaledTouchSlop
    private val scroller = OverScroller(host.context)
    private var tracker: VelocityTracker? = null
    private var lastY = 0f
    private var downY = 0f
    private var dragging = false

    private val fling = object : Runnable {
        override fun run() {
            val picture = host.background as? PanningBitmapDrawable ?: return
            if (!scroller.computeScrollOffset()) {
                return
            }
            if (picture.panTo(scroller.currY.toFloat(), host.height)) {
                host.invalidate()
            }
            if (!scroller.isFinished) {
                host.postOnAnimation(this)
            }
        }
    }

    fun onIntercept(ev: MotionEvent): Boolean {
        val picture = host.background as? PanningBitmapDrawable ?: return false
        when (ev.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                scroller.abortAnimation()
                host.removeCallbacks(fling)
                lastY = ev.y
                downY = ev.y
                dragging = false
                tracker?.recycle()
                tracker = VelocityTracker.obtain()
                tracker?.addMovement(ev)
            }
            MotionEvent.ACTION_MOVE -> {
                tracker?.addMovement(ev)
                if (!dragging && abs(ev.y - downY) > slop) {
                    dragging = true
                    lastY = downY
                    host.parent?.requestDisallowInterceptTouchEvent(true)
                }
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> finish(ev, picture)
        }
        return dragging
    }

    fun onTouch(ev: MotionEvent): Boolean {
        val picture = host.background as? PanningBitmapDrawable ?: return false
        when (ev.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                scroller.abortAnimation()
                host.removeCallbacks(fling)
                lastY = ev.y
                downY = ev.y
                dragging = false
                tracker?.recycle()
                tracker = VelocityTracker.obtain()
                tracker?.addMovement(ev)
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                tracker?.addMovement(ev)
                if (!dragging && abs(ev.y - downY) > slop) {
                    dragging = true
                    lastY = downY
                }
                if (dragging) {
                    val dy = lastY - ev.y
                    lastY = ev.y
                    if (picture.panBy(dy, host.height)) {
                        host.invalidate()
                    }
                }
                return dragging
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                finish(ev, picture)
                return dragging
            }
        }
        return dragging
    }

    private fun finish(ev: MotionEvent, picture: PanningBitmapDrawable) {
        val wasDragging = dragging
        tracker?.addMovement(ev)
        tracker?.computeCurrentVelocity(1000)
        val velocity = tracker?.yVelocity ?: 0f
        tracker?.recycle()
        tracker = null
        dragging = false
        if (!wasDragging || ev.actionMasked != MotionEvent.ACTION_UP) {
            return
        }
        scroller.fling(
            0,
            picture.offsetPx(),
            0,
            (-velocity).toInt(),
            0,
            0,
            0,
            picture.maxOffset(host.height).toInt()
        )
        host.postOnAnimation(fling)
    }
}
