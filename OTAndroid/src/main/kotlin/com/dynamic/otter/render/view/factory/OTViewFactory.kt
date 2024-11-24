package com.dynamic.otter.render.view.factory

import android.content.Context
import android.view.View
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.view.basic.AnimationView
import com.dynamic.otter.render.view.basic.Column
import com.dynamic.otter.render.view.basic.OTList
import com.dynamic.otter.render.view.basic.Image
import com.dynamic.otter.render.view.basic.ProgressView
import com.dynamic.otter.render.view.basic.Row
import com.dynamic.otter.render.view.basic.Text
import com.dynamic.otter.render.view.basic.OTAbsoluteLayout
import com.dynamic.otter.render.view.basic.Spacer

@Suppress("UNCHECKED_CAST")
object OTViewFactory {
    fun <T : View> createView(
        context: Context,
        viewName: String,
        customViewClass: String? = null
    ): T {
        if (viewName == TemplateKey.CUSTOM && customViewClass != null) {
            return newInstance<T>(customViewClass, context) as T
        }

        return when (viewName) {
            TemplateKey.COLUMN -> Column(context) as T
            TemplateKey.ROW -> Row(context) as T
            TemplateKey.TEXT -> Text(context) as T
            TemplateKey.IMAGE -> Image(context) as T
            TemplateKey.SPACER -> Spacer(context) as T
            TemplateKey.OT_LIST -> OTList(context) as T
            TemplateKey.PROGRESS->ProgressView(context) as T
            TemplateKey.ANIMATION->AnimationView(context) as T
            else -> {
                throw IllegalArgumentException("unknown type")
            }
        }
    }

    private fun <T : View> newInstance(
        clazz: String?,
        context: Context
    ) = if (clazz != null) {
        val clz = Class.forName(clazz).getConstructor(Context::class.java)
        clz.newInstance(context) as T
    } else {
        OTAbsoluteLayout(context)
    }
}