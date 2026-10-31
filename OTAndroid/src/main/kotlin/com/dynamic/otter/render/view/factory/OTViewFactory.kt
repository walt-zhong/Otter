package com.dynamic.otter.render.view.factory

import android.content.Context
import android.view.View
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.view.basic.AnimationView
import com.dynamic.otter.render.view.basic.CheckBox
import com.dynamic.otter.render.view.basic.Column
import com.dynamic.otter.render.view.basic.Image
import com.dynamic.otter.render.view.basic.Input
import com.dynamic.otter.render.view.basic.OTList
import com.dynamic.otter.render.view.basic.ProgressView
import com.dynamic.otter.render.view.basic.Radio
import com.dynamic.otter.render.view.basic.Row
import com.dynamic.otter.render.view.basic.Spacer
import com.dynamic.otter.render.view.basic.Switch
import com.dynamic.otter.render.view.basic.Text

object OTViewFactory {
    fun <T : View> createView(context: Context, viewName: String): T {
        val view = when (viewName) {
            TemplateKey.COLUMN -> Column(context)
            TemplateKey.ROW -> Row(context)
            TemplateKey.TEXT -> Text(context)
            TemplateKey.IMAGE -> Image(context)
            TemplateKey.SPACER -> Spacer(context)
            TemplateKey.OT_LIST -> OTList(context)
            TemplateKey.PROGRESS -> ProgressView(context)
            TemplateKey.ANIMATION -> AnimationView(context)
            TemplateKey.INPUT -> Input(context)
            TemplateKey.CHECKBOX -> CheckBox(context)
            TemplateKey.RADIO -> Radio(context)
            TemplateKey.SWITCH -> Switch(context)
            else -> throw IllegalArgumentException("unknown type $viewName")
        }
        @Suppress("UNCHECKED_CAST")
        return view as T
    }
}
