package com.dynamic.otter.demo

import android.content.Context
import android.content.Intent
import android.widget.Toast

object DemoRoutes {
    fun open(context: Context, page: String) {
        val target = pages[page]
        if (target == null) {
            Toast.makeText(context, "没有这个示例", Toast.LENGTH_SHORT).show()
            return
        }
        context.startActivity(Intent(context, target))
    }

    private val pages = mapOf(
        "layout" to LayoutDemoActivity::class.java,
        "text" to LayoutTextTemplateActivity::class.java,
        "list" to ListTemplateActivity::class.java,
        "progress" to ProgressTemplateActivity::class.java,
        "weather" to WeatherCardTemplateActivity::class.java,
        "animation" to AnimationActivity::class.java,
        "scaffold" to ScaffoldActivity::class.java,
        "tabs" to TabLayoutVp2Activity::class.java
    )
}
