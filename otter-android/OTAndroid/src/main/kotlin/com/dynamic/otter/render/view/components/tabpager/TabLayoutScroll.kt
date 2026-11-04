package com.dynamic.otter.render.view.components.tabpager

import android.content.Context
import android.graphics.Color
import android.util.AttributeSet
import android.view.View
import android.widget.FrameLayout
import com.dynamic.otter.utils.ScreenUtils

open class TabLayoutScroll @JvmOverloads constructor(
    context: Context,
    attributeSet: AttributeSet? = null,
    defStyle: Int = 0
) : FrameLayout(context, attributeSet, defStyle), ITabLayout {
    private var horizontalRecyclerView: HorizontalRecyclerView? = null
    private var spaceVertical: Int = 0
    private var spaceHorizontal: Int = 0
    private var indicatorView: IViewIndicator

    init {
        horizontalRecyclerView = HorizontalRecyclerView((context))
        indicatorView = IndicatorLineView(context)
        val indicator = (indicatorView as IndicatorLineView).getIndicator()
        indicator?.apply {
            setIndicatorHeight(10)
            setIndicatorColor(Color.RED)
        }

        setSpaceVertical(ScreenUtils.dpAdapt(context, 20f))
        setSpaceHorizontal(ScreenUtils.dpAdapt(context, 8f))
        addTab()
    }

    fun addTab() {
        removeAllViews()

        addView(
            horizontalRecyclerView,
            childCount,
            LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        )

        addView(
            indicatorView as IndicatorLineView,
            LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT)
        )
    }

    fun setSpaceVertical(spaceVertical: Int) {
        this.spaceVertical = spaceVertical
    }

    fun setSpaceHorizontal(spaceHorizontal: Int) {
        this.spaceHorizontal = spaceHorizontal
    }

    fun setAdapter(adapter: TabAdapter<*>) {
        if (horizontalRecyclerView?.adapter == null) {
            val linearItemDecoration = LinearItemDecoration(adapter)
            linearItemDecoration.setSpaceHorizontal(11)
            linearItemDecoration.setSpaceVertical(10)
            horizontalRecyclerView?.addItemDecoration(linearItemDecoration)
        }

        horizontalRecyclerView?.adapter = adapter
    }

    fun getHorizontalRecyclerView(): HorizontalRecyclerView {
        return horizontalRecyclerView!!
    }

    fun getIndicatorView(): IViewIndicator? {
        return indicatorView
    }

    override fun <T : View> getView(): T {
        return this as T
    }

    override fun <T : ITabLayout> setIndicatorView(indicator: IViewIndicator) {
        removeView(this.indicatorView.getView())
        removeView(indicatorView.getView())
        addView(indicatorView.getView(), 0)
    }
}