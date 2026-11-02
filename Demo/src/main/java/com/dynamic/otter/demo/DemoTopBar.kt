package com.dynamic.otter.demo

import android.view.View
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.dynamic.otter.nav.PageStack

object DemoTopBar {
    fun bind(activity: AppCompatActivity, title: String, showBack: Boolean) {
        val label = activity.findViewById<TextView>(R.id.demo_top_title)
        val back = activity.findViewById<View>(R.id.demo_top_back)
        label.text = title
        val start = if (showBack) 0 else activity.resources.displayMetrics.density.times(16).toInt()
        label.setPadding(start, label.paddingTop, label.paddingRight, label.paddingBottom)
        back.visibility = if (showBack) View.VISIBLE else View.GONE
        if (showBack) {
            back.setOnClickListener {
                val stack = PageStack.find(activity)
                if (stack != null && stack.pop()) {
                    return@setOnClickListener
                }
                activity.finish()
            }
        }
    }
}
