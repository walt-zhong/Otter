package com.dynamic.otter.render.view.components.tabpager

import android.content.Context
import android.graphics.Typeface
import android.util.AttributeSet
import android.view.ViewGroup
import android.widget.LinearLayout
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import androidx.viewpager2.widget.ViewPager2
import com.dynamic.otter.render.view.components.tabpager.adapter.FragPageAdapter
import com.dynamic.outter.R

class TabPager @JvmOverloads constructor(
    context: Context,
    attr: AttributeSet? = null,
    defStyle: Int = 0
) : LinearLayout(context, attr, defStyle) {
    private var tabLayoutScroll: TabLayoutScroll
    private var viewPager2: ViewPager2

    init {
        orientation = VERTICAL
        tabLayoutScroll = TabLayoutScroll(context)
        viewPager2 = ViewPager2(context)
        viewPager2.overScrollMode = OVER_SCROLL_NEVER

        this.addView(tabLayoutScroll)
        this.addView(viewPager2)
    }

    fun init(tabDataList: MutableList<String>) {
        val fragmentPageAdapter: FragPageAdapter<String> =
            object : FragPageAdapter<String>(context as FragmentActivity) {
                override fun createFragment(bean: String, position: Int): Fragment {
                    return getListBean()[position]
                        .let { FragmentTab.newInstance("zhongxj", it) }
                }

                override fun getTabLayoutID(position: Int, bean: String): Int {
                    return R.layout.item_tab_gradient
                }

                override fun onTabScrolled(
                    holderCurrent: TabViewHolder,
                    positionCurrent: Int,
                    fromLeft2RightCurrent: Boolean,
                    positionOffsetCurrent: Float,
                    holder2: TabViewHolder,
                    position2: Int,
                    fromLeft2Right2: Boolean,
                    positionOffset2: Float
                ) {
                    super.onTabScrolled(
                        holderCurrent,
                        positionCurrent,
                        fromLeft2RightCurrent,
                        positionOffsetCurrent,
                        holder2,
                        position2,
                        fromLeft2Right2,
                        positionOffset2
                    )

                    val textViewCurrent: TabGradientTextView = holderCurrent.getView(R.id.tv)
                    val textView2: TabGradientTextView = holder2.getView(R.id.tv)
                    textViewCurrent.setDirection(if (fromLeft2RightCurrent) TabGradientTextView.DIRECTION_FROM_LEFT else TabGradientTextView.DIRECTION_FROM_RIGHT)
                        .setProgress(positionOffsetCurrent)
                    textView2.setDirection(if (fromLeft2Right2) TabGradientTextView.DIRECTION_FROM_LEFT else TabGradientTextView.DIRECTION_FROM_RIGHT)
                        .setProgress(positionOffset2)
                }

                override fun bindDataToTab(
                    holder: TabViewHolder,
                    position: Int,
                    bean: String,
                    isSelected: Boolean
                ) {
                    val textView: TabGradientTextView = holder.getView(R.id.tv)
                    if (isSelected) {
                        textView.setTypeface(Typeface.defaultFromStyle(Typeface.BOLD))
                        //因为            public void onPageScrolled(int position, float positionOffset, int positionOffsetPixels) {
                        //positionOffset没有为1的时候
                        //必须
                        textView.setProgress(1f)
                    } else {
                        textView.setTypeface(Typeface.defaultFromStyle(Typeface.NORMAL))
                        //因为快速滑动时，            public void onPageScrolled(int position, float positionOffset, int positionOffsetPixels) {
                        //positionOffset不会出现0
                        //必须
                        textView.setProgress(0f)
                    }
                    textView.text = bean
                }
            }

        val tabAdapter: TabAdapter<String> =
            TabMediator<String>(tabLayoutScroll, viewPager2).setAdapter(fragmentPageAdapter)!!

        fragmentPageAdapter.add<FragPageAdapter<String>>(tabDataList)
        tabAdapter.add<TabAdapter<String>>(tabDataList)
    }

    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        super.onLayout(changed, l, t, r, b)
        val params = tabLayoutScroll.layoutParams
        params.width = ViewGroup.LayoutParams.MATCH_PARENT
        params.height = 120
        tabLayoutScroll.layoutParams = params

        val vparams = viewPager2.layoutParams
        vparams.width = ViewGroup.LayoutParams.MATCH_PARENT
        vparams.height = ViewGroup.LayoutParams.MATCH_PARENT
        viewPager2.layoutParams = vparams
    }
}