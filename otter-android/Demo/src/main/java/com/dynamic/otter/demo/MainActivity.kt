package com.dynamic.otter.demo

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.dynamic.otter.ExpansionCenter
import kotlin.math.max

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO)
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContentView(R.layout.activity_main)
        DemoTopBar.bind(this, "Otter", showBack = false)
        ExpansionCenter.instance.registerPageOpener { context, page ->
            DemoRoutes.open(context, page)
        }
        applyInsets()
        val list = findViewById<LinearLayout>(R.id.nav_list)
        val sections = DemoRoutes.sections.toMutableList()
        bundleEntry()?.let { entry ->
            sections += DemoRoutes.Section("调试", listOf(entry))
        }
        sections.forEachIndexed { index, section ->
            list.addView(sectionLabel(section.title, index == 0))
            section.entries.forEach { entry ->
                list.addView(entryCard(entry))
            }
        }
    }

    private fun bundleEntry(): DemoRoutes.Entry? {
        return try {
            Class.forName("com.dynamic.otter.demo.BundleDebugActivity")
            DemoRoutes.Entry(
                "bundle",
                "生成",
                "输入 query，向后端要一个签名包并渲染",
                "服务"
            )
        } catch (_: ClassNotFoundException) {
            null
        }
    }

    private fun applyInsets() {
        val root = findViewById<View>(R.id.main)
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            val ime = insets.getInsets(WindowInsetsCompat.Type.ime())
            view.setPadding(bars.left, bars.top, bars.right, max(bars.bottom, ime.bottom))
            insets
        }
        ViewCompat.requestApplyInsets(root)
    }

    private fun sectionLabel(title: String, first: Boolean): TextView {
        return TextView(this).apply {
            text = title
            setTextColor(0xFFC45C26.toInt())
            textSize = 11f
            val top = if (first) 8 else 22
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dp(top)
                bottomMargin = dp(8)
            }
        }
    }

    private fun entryCard(entry: DemoRoutes.Entry): View {
        val card = layoutInflater.inflate(R.layout.item_nav_entry, findViewById(R.id.nav_list), false)
        card.findViewById<TextView>(R.id.nav_title).text = entry.title
        card.findViewById<TextView>(R.id.nav_desc).text = entry.desc
        card.findViewById<TextView>(R.id.nav_tag).text = entry.tag
        val params = card.layoutParams as LinearLayout.LayoutParams
        params.bottomMargin = dp(12)
        card.layoutParams = params
        card.setOnClickListener {
            if (entry.page == "bundle") {
                startActivity(
                    Intent().setClassName(this, "com.dynamic.otter.demo.BundleDebugActivity")
                )
                return@setOnClickListener
            }
            DemoRoutes.open(this, entry.page)
        }
        return card
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }
}
