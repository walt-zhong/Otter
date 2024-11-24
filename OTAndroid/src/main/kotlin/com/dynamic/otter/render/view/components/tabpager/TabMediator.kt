package com.dynamic.otter.render.view.components.tabpager

import android.util.Log
import androidx.recyclerview.widget.RecyclerView
import androidx.recyclerview.widget.RecyclerView.OnScrollListener
import androidx.recyclerview.widget.RecyclerView.SCROLL_STATE_IDLE
import androidx.viewpager2.widget.ViewPager2
import androidx.viewpager2.widget.ViewPager2.OnPageChangeCallback
import com.dynamic.otter.render.view.components.tabpager.adapter.ITabPageAdapter
import kotlin.math.abs

class TabMediator<T : Any> : ITabMediator {
    private val TAG = "TabMediator"
    private var tabLayoutScroll: TabLayoutScroll
    private var viewPager2: ViewPager2
    private var positionScrollLast: Int = 0

    private var diff: Int = 0
    private var diffClick = -1
    private var toScroll = 0
    private var offsetXLast = 0
    private var offsetXLastClick = -1
    private var offsetXTouch = 0
    private var clickPositionLast = -1

    private var rvScrolledByVp = false
    private var rvScrolledByTouch = false
    private var scrolledByClick = false
    private var opClickLast = false

    private var tabAdapter: TabAdapter<T>? = null
    private var tabPageAdapter: ITabPageAdapter<T>? = null

    constructor(tabLayout: TabLayoutScroll, pViewPager2: ViewPager2) {
        this.tabLayoutScroll = tabLayout
        this.viewPager2 = pViewPager2

        val horizontalRecyclerView = tabLayoutScroll.getHorizontalRecyclerView()

        horizontalRecyclerView.addOnScrollListener(object : OnScrollListener() {
            override fun onScrolled(recyclerView: RecyclerView, dx: Int, dy: Int) {
                super.onScrolled(recyclerView, dx, dy)
                // 如果手指滑动的是tabLayout，则需要记录滑动的距离
                if (!rvScrolledByVp) {
                    rvScrolledByTouch = true
                    offsetXTouch -= dx
                }

                // indicator需要跟着滑动
                val viewHolder =
                    horizontalRecyclerView.findViewHolderForAdapterPosition(viewPager2.currentItem)

                if (viewHolder != null) {
                    val indicatorView = tabLayoutScroll.getIndicatorView()
                    if (indicatorView != null) {
                        val indicator = indicatorView.getIndicator()
                        if (indicator != null) {
                            val indicatorWidth = if (indicator.isMaxWidth()) {
                                viewHolder.itemView.width
                            } else {
                                indicator.getIndicatorSelectedWidth()
                            }

                            val indicatorHeight = if (indicator.isMaxHeight()) {
                                viewHolder.itemView.height
                            } else {
                                indicator.getIndicatorHeight()
                            }

                            val progress = viewHolder.itemView.left + viewHolder.itemView.width * 1f / 2 - indicator.getIndicatorWidth() / 2

                            indicator.setIndicatorWidth(indicatorWidth)
                            indicator.setIndicatorHeight(indicatorHeight)
                            indicator.setProgress(progress.toInt())
                        }
                    }
                } else {
                    // 若不可见，则width_indicator为0
                    tabLayoutScroll.getIndicatorView()?.getIndicator()
                        ?.setIndicatorWidth(0)?.invalidate()
                }

            }

            override fun onScrollStateChanged(recyclerView: RecyclerView, newState: Int) {
                super.onScrollStateChanged(recyclerView, newState)
                Log.d(TAG, "onScrollStateChanged: $newState")
            }
        })

        this.viewPager2.registerOnPageChangeCallback(object : OnPageChangeCallback() {
            override fun onPageSelected(position: Int) {
                super.onPageSelected(position)
                // 通知tabAdapter更新选中项
                tabAdapter?.setPositionSelected(viewPager2.currentItem)
            }

            /**注意：滑动很快的时候，即使到了另外的page,positionOffsetPixels不一定会出现0
             * @param position
             * @param positionOffset
             * @param positionOffsetPixels
             */
            override fun onPageScrolled(
                position: Int,
                positionOffset: Float,
                positionOffsetPixels: Int
            ) {
                super.onPageScrolled(position, positionOffset, positionOffsetPixels)
                val centerX = tabLayoutScroll.width * 1f / 2
                //若上次手指滑动了tabLayout,现在手指滑动了viewpager，则需要将tablayout复位
                if (rvScrolledByTouch && offsetXTouch != 0) {
                    horizontalRecyclerView.stopScroll()
                    // 将标志置为不是由手指滑动tabLayout
                    rvScrolledByVp = true
                    horizontalRecyclerView.scrollBy(offsetXTouch, 0)
                    rvScrolledByVp = false
                    rvScrolledByTouch = false
                    offsetXTouch = 0
                    return
                }

                if (scrolledByClick) {
                    if ((position == viewPager2.currentItem - 1 || position == viewPager2.currentItem)) {
                        val viewHolder =
                            horizontalRecyclerView
                                .findViewHolderForAdapterPosition(viewPager2.currentItem)

                        if (viewHolder != null) {
                            // 如果indicator想要指向正中间，则计算TabLayout需要滑动的距离
                            if (diffClick == -1) {
                                diffClick = (viewHolder.itemView.left + viewHolder.itemView.width * 1f / 2 - centerX).toInt()
                            }

                            // 获取TabLayout的偏移量，它永远小于等于0
                            if (offsetXLastClick == -1) {
                                offsetXLastClick = horizontalRecyclerView.getOffsetX()
                            }

                            if (positionOffset != 0f) {
                                // scrollBy调用一次，onScrolled回调一次
                                // 标志不是由手指滑动的tabLayout

                                rvScrolledByVp = true
                                if (diffClick > 0) {
                                    horizontalRecyclerView.scrollTo(
                                        (offsetXLastClick - (diffClick * positionOffset)).toInt(),
                                        0
                                    )
                                } else if (diffClick < 0) {
                                    horizontalRecyclerView.scrollTo(
                                        (offsetXLastClick - (diffClick * (1 - positionOffset))).toInt(),
                                        0
                                    )
                                }

                                rvScrolledByVp = false
                            }
                        } else {
                            // 不可见的情况下将indicatorWidth设置为0
                            tabLayoutScroll.getIndicatorView()
                                ?.getIndicator()
                                ?.setIndicatorWidth(0)
                                ?.invalidate()
                        }
                    }

                    positionScrollLast = position
                    return
                }

                // 手指左右滑动ViewPager则会触发下面的逻辑
                val viewHolder =
                    horizontalRecyclerView.findViewHolderForAdapterPosition(position)
                if (viewHolder != null) {
                    val widthHalf = viewHolder.itemView.width * 1f / 2
                    val left = viewHolder.itemView.left
                    val space = horizontalRecyclerView.getItemDecoration().getSpaceHorizontal()

                    val viewHolderBehind =
                        horizontalRecyclerView.findViewHolderForAdapterPosition(position + 1)

                    if (position == 0) {
                        // TabLayout 刚显示，indicator会指向第0个item
                        diff = 0
                        offsetXLast = 0
                        if (viewHolderBehind != null) {
                            // 计算indicator指向下一个Item需要滑动的距离
                            toScroll = (widthHalf + space + viewHolderBehind.itemView.width * 1f / 2).toInt()
                        }
                    }else if(positionScrollLast < position){
                        if(viewHolderBehind != null){
                            //indicator想要指向正中间，计算TabLayout需要滑动的距离
                            diff =
                                (viewHolderBehind.itemView.left + viewHolderBehind.itemView.width * 1f / 2 - centerX).toInt()
                            //下一个item都在正中间的前面，无需滑动，而且可以避免出现负数导致recyclerView抖动
                            if (diff < 0) {
                                diff = 0
                            }

                            // 获取上次tabLayout的偏移两，永远<=0
                            offsetXLast = horizontalRecyclerView.getOffsetX()
                            // 计算indicator指向下一个item需要滑动的距离
                            toScroll =
                                (widthHalf + space + viewHolderBehind.itemView.width * 1f / 2).toInt()
                        }

                    } else if (positionScrollLast > position) {
                        // 表示从page index滑动到了page index-1
                        // indicator想要指向正中间，计算TabLayout需要滑动的距离
                        diff = (left + widthHalf - centerX).toInt()
                        // position 的item在正中间的后面，无需滑动，而且可以避免出现正数导致recyclerView抖动
                        if (diff > 0) {
                            diff = 0
                        }
                        //获取上次tabLayout的偏移量，永远<=0
                        offsetXLast = horizontalRecyclerView.getOffsetX()
                        if (viewHolderBehind != null) {
                            //计算indicator指向position的item需要滑动的距离
                            toScroll = (widthHalf + space + viewHolderBehind.itemView.width * 1f / 2).toInt()
                        }
                    } else if (opClickLast) {
                        //positionScrollLast==position,并且上次操作是点击item,
                        if (clickPositionLast == position) {
                            //说明现在是正要从page index 滑动到page index+1
                            if (viewHolderBehind != null) {
                                //indicator想要指向正中间，计算TabLayout需要滑动的距离
                                diff = (viewHolderBehind.itemView.left + viewHolderBehind.itemView.width * 1f / 2 - centerX).toInt()
                                //获取上次tablayout的偏移量，永远<=0
                                offsetXLast = horizontalRecyclerView.getOffsetX()
                                //计算indicator指向position的item需要滑动的距离
                                toScroll = (widthHalf + space + viewHolderBehind.itemView.width * 1f / 2).toInt()
                            }
                        }
                        opClickLast = false
                    }
                    //diff==0,无需滑动，positionOffset==0,无需滑动，当前position和上次滑动的position相等，才执行滑动操作
                    if (
                        diff != 0
                        && positionOffset != 0f
                        && positionScrollLast == position
                    ) {
                        //标志，tabLayout滑动，不是因为手指滑动tablayout导致的
                        rvScrolledByVp = true
                        if (diff > 0) {
                            //scrollBy调用一次，onScrolled回调一次
                            //手指往左滑动，positionOffset由小变大
                            horizontalRecyclerView.scrollTo(
                                (offsetXLast - (diff * positionOffset)).toInt(),
                                0
                            )
                        } else {
                            //手指往右滑动，positionOffset由大变小
                            horizontalRecyclerView.scrollTo(
                                (offsetXLast - (diff * (1 - positionOffset))).toInt(),
                                0
                            )
                        }

                        // 标志复位
                        rvScrolledByVp = false
                    }
                    //如果是最大宽度,计算指示器宽度,指示器宽度由小变大，或者是由大变小
                    //如果是isMax2Width(),计算Width_indicator,Width_indicator由小变大，或者是由大变小

                    val w1 = if (viewHolderBehind != null) {
                        val direction =
                            if (viewHolder.itemView.width > (viewHolderBehind.itemView.width)) {
                                -1
                            } else {
                                1
                            }

                        val widthDiff = viewHolderBehind.itemView.width - viewHolder.itemView.width
                        viewHolder.itemView.width + (direction * abs(widthDiff) * positionOffset).toInt()
                    } else {
                        0
                    }

                    val w2 = if (viewHolderBehind != null) {
                        val direction =
                            if (viewHolderBehind.itemView.width > (viewHolder.itemView.width)) {
                                -1
                            } else {
                                1
                            }

                        val widthDiff = viewHolderBehind.itemView.width - viewHolder.itemView.width

                        viewHolderBehind.itemView.width + (direction * abs(widthDiff) * (1 - positionOffset)).toInt()
                    } else {
                        0
                    }

                    val w = if (positionOffset == 0f) {
                        viewHolder.itemView.width
                    } else {
                        if (positionScrollLast <= position) {
                            w1
                        } else {
                            w2
                        }
                    }

                    //如果不是最大宽度,计算指示器宽度,指示器宽度由小变大再变小，2个item中间时最大
                    val indicator = tabLayoutScroll.getIndicatorView()?.getIndicator()
                    if (indicator != null) {

                        val temWidth =
                            indicator.getIndicatorMaxWidth() * (0.5 - abs(0.5 - positionOffset))
                        val indicatorWidth = if (indicator.isMaxWidth()) {
                            w
                        } else {
                            indicator.getIndicatorSelectedWidth().coerceAtLeast(
                                indicator.getIndicatorSelectedWidth() + if (positionOffset == 0f) { 0 } else { temWidth.toInt() }
                            )
                        }

                        val indicatorHeight = if(indicator.isMaxHeight()){
                            viewHolder.itemView.height
                        }else{
                            indicator.getIndicatorHeight()
                        }

                        val progress = left + widthHalf - indicator.getIndicatorWidth()/2 + toScroll*positionOffset


                        indicator.setIndicatorWidth(indicatorWidth)
                        indicator.setIndicatorHeight(indicatorHeight)
                        indicator.setProgress(progress.toInt())

                        if(toScroll != 0){
                            //手指往左滑动，positionOffset由小变大
                            //手指往右滑动，positionOffset由大变小
                            if(viewHolderBehind != null){
                                tabPageAdapter?.onTabScrolled(
                                    viewHolder as TabViewHolder,
                                    position,
                                    false,
                                    1-positionOffset,
                                    viewHolderBehind as TabViewHolder,
                                    position+1,
                                    true,
                                    positionOffset
                                    )
                            }
                        }
                    }
                }else{
                    //viewpager嵌套viewpager的时候，内层viewpager向右滑动了以后又向左滑动，会导致tablayout
                    //position对应的item不可见，所以要滑动到对应的position
                    horizontalRecyclerView.scrollToPosition(position)
                    val viewHolder1 =
                        horizontalRecyclerView.findViewHolderForAdapterPosition(position)

                    //scrollToPosition一调用，不会立马滑动完毕，所以还会有存在null的时候，
                    if(viewHolder1 != null){
                        val widthHalf = viewHolder1.itemView.width * 1f /2
                        val left = viewHolder1.itemView.left
                        val indicator = tabLayoutScroll.getIndicatorView()?.getIndicator()
                        if(indicator != null){
                            val indicatorWidth = if(indicator.isMaxWidth()){
                                viewHolder1.itemView.width
                            }else{
                                indicator.getIndicatorSelectedWidth()
                            }

                            val indicatorHeight = if(indicator.isMaxHeight()){
                                viewHolder1.itemView.height
                            }else{
                                indicator.getIndicatorHeight()
                            }

                            val progress = left + widthHalf - indicator.getIndicatorWidth()*1f/2
                            indicator.setIndicatorWidth(indicatorWidth)
                            indicator.setIndicatorHeight(indicatorHeight)
                            indicator.setProgress(progress.toInt())
                        }
                    } else {
                        tabLayoutScroll.getIndicatorView()
                            ?.getIndicator()
                            ?.setIndicatorWidth(0)
                            ?.invalidate()
                    }
                }

                positionScrollLast = position
            }

            override fun onPageScrollStateChanged(state: Int) {
                super.onPageScrollStateChanged(state)
                if(state == SCROLL_STATE_IDLE){
                    // 记录上次操作的是点击item
                    if(scrolledByClick){
                        clickPositionLast = viewPager2.currentItem
                        opClickLast = true
                    }

                    // 标志复位
                    scrolledByClick = false
                    diffClick = -1
                    offsetXLastClick = -1
                }
            }
        })

        tabAdapter = object: TabAdapter<T>(){
            override fun onItemClick(tabViewHolder: TabViewHolder, position: Int, bean: T) {
                //点击tabLayout的item,会先回调onPageSelected,然后回调onPageScrolled
                //标志复位
                rvScrolledByTouch = false
                offsetXTouch = 0
                //标志：tabLayout的滑动是由点击item触发的
                scrolledByClick = true
                viewPager2.currentItem = position

                //让indicator立马指向currentItem
                val holder =
                    horizontalRecyclerView.findViewHolderForAdapterPosition(viewPager2.currentItem)
                if(holder != null){
                    val indicator = tabLayoutScroll.getIndicatorView()?.getIndicator()

                    if(indicator != null){
                        val indicatorWidth = if(indicator.isMaxWidth()){
                            holder.itemView.width
                        }else{
                            indicator.getIndicatorSelectedWidth()
                        }

                        val indicatorHeight = if(indicator.isMaxHeight()){
                            holder.itemView.height
                        }else{
                            indicator.getIndicatorHeight()
                        }

                        val progress = holder.itemView.left + holder.itemView.width*1f/2- indicator.getIndicatorWidth()/2

                        indicator.setIndicatorWidth(indicatorWidth)
                        indicator.setIndicatorHeight(indicatorHeight)
                        indicator.setProgress(progress.toInt())
                    }else{
                        // 不可见，widthIndicator 为0
                        tabLayoutScroll.getIndicatorView()
                            ?.getIndicator()
                            ?.setIndicatorWidth(0)
                            ?.invalidate()
                    }

                    tabPageAdapter?.onTabClick(tabViewHolder,position,bean)
                }

            }

            override fun getItemLayoutID(position: Int, bean: T): Int {
                return tabPageAdapter?.getTabLayoutID(position, bean)!!
            }

            override fun bindDataToView(
                holder: TabViewHolder,
                position: Int,
                bean: T,
                isSelected: Boolean
            ) {
               tabPageAdapter?.bindDataToTab(holder, position, bean, isSelected)
            }
        }
    }

    fun setAdapter(tabPageAdapter: ITabPageAdapter<T>)
            : TabAdapter<T>? {
        this.tabPageAdapter = tabPageAdapter
        tabAdapter?.let { tabLayoutScroll.setAdapter(it) }
        viewPager2.adapter = tabPageAdapter.getPageAdapter()
        return tabAdapter
    }
}