package com.dynamic.otter.demo

import android.os.Bundle
import android.widget.FrameLayout
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import com.dynamic.otter.render.view.components.tabpager.TabPager

class TabLayoutVp2Activity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val list: MutableList<String> = mutableListOf()
        list.add("关注")
        list.add("推荐")
        list.add("视频")
        list.add("Java")
        list.add("Android")
        list.add("kotlin")
        list.add("小视频")
        list.add("新闻")
        list.add("探索")
        list.add("在家上课")
        list.add("手机")
        list.add("动漫")
        list.add("通信")
        list.add("影视")
        list.add("互联网")
        list.add("设计")
        list.add("家电")
        list.add("平板")
        list.add("网球")
        list.add("军事")
        list.add("羽毛球")
        list.add("奢侈品")
        list.add("美食")
        list.add("瘦身")
        list.add("幸福里")
        list.add("棋牌")
        list.add("奇闻")
        list.add("艺术")
        list.add("减肥")
        list.add("电玩")
        list.add("台球")
        list.add("八卦")
        list.add("酷玩")
        list.add("彩票")
        list.add("动漫")
        val tabPagerView = TabPager(this)
        tabPagerView.init(list)
        setContentView(R.layout.activity_tab_layout_vp2)

        val container = findViewById<FrameLayout>(R.id.tab_container)
        container.addView(tabPagerView)
    }
}