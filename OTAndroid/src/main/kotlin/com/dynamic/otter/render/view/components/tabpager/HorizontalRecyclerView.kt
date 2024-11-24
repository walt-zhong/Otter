package com.dynamic.otter.render.view.components.tabpager

import android.content.Context
import android.util.AttributeSet
import android.view.MotionEvent
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import androidx.recyclerview.widget.SimpleItemAnimator
import kotlin.math.abs

class HorizontalRecyclerView @JvmOverloads constructor(
    context: Context,
    attributeSet: AttributeSet? = null,
    defStyle: Int = 0
) : RecyclerView(context, attributeSet, defStyle) {
    private var downX: Int = 0
    private var downY: Int = 0

    private lateinit var linearItemDecoration: LinearItemDecoration
    private var offsetX = 0


    init {
        addOnScrollListener(object : OnScrollListener() {
            override fun onScrolled(recyclerView: RecyclerView, dx: Int, dy: Int) {
                super.onScrolled(recyclerView, dx, dy)
                offsetX -= dx
            }
        })

        val simpleItemAnimator = itemAnimator as SimpleItemAnimator
        simpleItemAnimator.supportsChangeAnimations = false
    }

    override fun onInterceptTouchEvent(e: MotionEvent?): Boolean {
        when (e?.action) {
            MotionEvent.ACTION_DOWN -> {
                downX = e.x.toInt()
                downY = e.y.toInt()
            }

            MotionEvent.ACTION_MOVE -> {
                val moveX = e.x.toInt()
                val moveY = e.y.toInt()

                val dx = moveX - downX
                val dy = moveY - downY

                downX = moveX
                downY = moveY

                if (abs(dx) > abs(dy) &&
                    ((dx > 0) && canScrollHorizontally(-1))
                    || (dx < 0) && canScrollHorizontally(1)
                ) {
                    requestDisallowInterceptTouch(true)
                }
            }

        }
        return super.onInterceptTouchEvent(e)
    }

    private fun requestDisallowInterceptTouch(disallowInterceptTouchEvent: Boolean) {
        val parent = parent
        parent?.requestDisallowInterceptTouchEvent(disallowInterceptTouchEvent)
    }

    /**
     * x 为正，表示手指往左边滑动，为负，表示手指王右边滑动
     */
    override fun scrollBy(x: Int, y: Int) {
        super.scrollBy(x, y)
    }

    /**
     * x<=0
     * 比如 x=0,表示滑动到RecyclerView最左边，完全显示第一个item,
     * 比如 x=-100,表示RecyclerView左边100像素的界面被隐藏
     *
     * @param x
     * @param y
     */
    override fun scrollTo(x: Int, y: Int) {
        scrollBy(offsetX - x, y)
    }

    fun getOffsetX(): Int {
        return offsetX
    }

    override fun setAdapter(adapter: Adapter<*>?) {
        layoutManager = LinearLayoutManager(
            context,
            LinearLayoutManager.HORIZONTAL,
            false
        )
        super.setAdapter(adapter)
    }

    override fun addItemDecoration(decor: ItemDecoration, index: Int) {
        try {
            this.linearItemDecoration = decor as LinearItemDecoration
        } catch (e: Exception) {
            throw IllegalAccessError("you can only use LinearItemDecoration")
        }

        super.addItemDecoration(decor, index)
    }

    override fun addItemDecoration(decor: ItemDecoration) {
        try {
            this.linearItemDecoration = decor as LinearItemDecoration
        } catch (e: Exception) {
            throw IllegalAccessError("you can only use LinearItemDecoration")
        }
        super.addItemDecoration(decor)
    }

    override fun getItemDecorationAt(index: Int): ItemDecoration {
        return linearItemDecoration
    }

    fun getItemDecoration(): LinearItemDecoration {
        return linearItemDecoration
    }


    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
    }
}