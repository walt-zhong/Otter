package com.dynamic.otter.render.view.basic

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.view.View.MeasureSpec
import android.view.ViewGroup
import android.view.ViewGroup.MarginLayoutParams
import android.widget.FrameLayout
import androidx.annotation.Keep
import androidx.core.widget.NestedScrollView
import com.dynamic.otter.render.view.attr.ColumnAttr
import com.dynamic.otter.render.view.attr.ViewAttr
import com.dynamic.otter.render.view.basic.capability.IStyleBindingCapability

@Keep
class Column : OTAbsoluteLayout, IStyleBindingCapability {
    var scrollContent: ViewGroup? = null
        private set

    private var installingScroll = false

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
