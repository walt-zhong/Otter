package com.dynamic.otter.demo

import android.view.View
import android.view.ViewGroup
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.dynamic.otter.OTEngine
import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.nav.Ime
import com.dynamic.otter.utils.AssetsUtils
import kotlin.math.max

object TemplateScreen {
    fun show(
        activity: AppCompatActivity,
        container: ViewGroup,
        templatePath: String,
        dataPath: String? = null,
        onReady: ((View) -> Unit)? = null
    ) {
        Ime.install(activity)
        val root = activity.findViewById<View>(R.id.main)
        var insetsApplied = false
        var rendered = false
        var scheduled = false
        var templateContext: TemplateContext? = null
        var laidOutWidth = 0
        var laidOutHeight = 0

        fun render() {
            if (!insetsApplied || container.width <= 0 || container.height <= 0) {
                return
            }
            // 布局过程中改尺寸会被丢掉，等这一轮结束再排。
            if (container.isInLayout) {
                if (!scheduled) {
                    scheduled = true
                    container.post {
                        scheduled = false
                        render()
                    }
                }
                return
            }
            if (rendered) {
                if (container.width == laidOutWidth && container.height == laidOutHeight) {
                    return
                }
                laidOutWidth = container.width
                laidOutHeight = container.height
                templateContext?.let { context ->
                    OTEngine.instance.relayout(
                        context,
                        OTEngine.OTViewPortSize(
                            container.width.toFloat(),
                            container.height.toFloat()
                        )
                    )
                }
                return
            }
            rendered = true
            laidOutWidth = container.width
            laidOutHeight = container.height
            val template = OTEngine.instance
                .init(activity)
                .buildTemplate("demo", "screen", templatePath)
            if (!dataPath.isNullOrBlank()) {
                template.setData(AssetsUtils.parseAssetsToString(activity, dataPath))
            }
            templateContext = template
            val view = OTEngine.instance.createAndroidView(
                template,
                OTEngine.OTViewPortSize(container.width.toFloat(), container.height.toFloat())
            ) ?: return
            container.addView(
                view,
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
            )
            onReady?.invoke(view)
        }

        container.addOnLayoutChangeListener { _, left, top, right, bottom, _, _, _, _ ->
            if (right - left > 0 && bottom - top > 0) {
                render()
            }
        }
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            // enableEdgeToEdge 关掉了 adjustResize，键盘只通过 IME inset 报高度。
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            val ime = insets.getInsets(WindowInsetsCompat.Type.ime())
            val bottom = max(bars.bottom, ime.bottom)
            insetsApplied = true
            if (view.paddingLeft != bars.left || view.paddingTop != bars.top ||
                view.paddingRight != bars.right || view.paddingBottom != bottom
            ) {
                view.setPadding(bars.left, bars.top, bars.right, bottom)
                view.requestLayout()
            }
            insets
        }
        ViewCompat.requestApplyInsets(root)
    }
}
