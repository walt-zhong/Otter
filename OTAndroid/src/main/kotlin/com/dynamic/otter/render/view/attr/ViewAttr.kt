package com.dynamic.otter.render.view.attr

import android.view.View
import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.template.OTFlexBox

open class ViewAttr {
    var id: Int = 0
    var width: String = "0"
    var height: String = "0"
    var background: String? = null
    var onClick: String? = null
    var leftTopRadius: String? = null
    var leftBottomRadius: String? = null
    var rightTopRadius: String? = null
    var rightBottomRadius: String? = null
    var radius: String? = null
    var borderColor: String? = null
    var borderWidth: String? = null
    var padding: String? = null
    var paddingStart: String? = null
    var paddingEnd: String? = null
    var paddingTop: String? = null
    var paddingBottom: String? = null
    lateinit var flexbox: OTFlexBox

    fun bind(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
        attrs.forEach { (name, raw) ->
            if (!applyCommon(name, raw, scope)) {
                applyOwn(name, raw, scope)
            }
        }
        flexbox = OTFlexBox.create(this)
        return this
    }

    protected open fun applyOwn(name: String, raw: String, scope: TemplateContext) = Unit

    private fun applyCommon(name: String, raw: String, scope: TemplateContext): Boolean {
        val value = raw.extractExpValue(scope.data)
        when (name) {
            TemplateKey.ATTR_ID -> {
                val viewId = View.generateViewId()
                id = viewId
                scope.viewIds[value] = viewId
            }

            TemplateKey.ATTR_WIDTH -> width = value
            TemplateKey.ATTR_HEIGHT -> height = value
            TemplateKey.ATTR_BACKGROUND -> background = value
            TemplateKey.ATTR_ONCLICK -> onClick = raw
            TemplateKey.ATTR_RADIUS -> radius = value
            TemplateKey.ATTR_LEFT_TOP_RADIUS -> leftTopRadius = value
            TemplateKey.ATTR_LEFT_BOTTOM_RADIUS -> leftBottomRadius = value
            TemplateKey.ATTR_RIGHT_TOP_RADIUS -> rightTopRadius = value
            TemplateKey.ATTR_RIGHT_BOTTOM_RADIUS -> rightBottomRadius = value
            TemplateKey.ATTR_BORDER_COLOR -> borderColor = value
            TemplateKey.ATTR_BORDER_WIDTH -> borderWidth = value
            TemplateKey.ATTR_PADDING -> padding = value
            TemplateKey.ATTR_PADDING_START -> paddingStart = value
            TemplateKey.ATTR_PADDING_END -> paddingEnd = value
            TemplateKey.ATTR_PADDING_TOP -> paddingTop = value
            TemplateKey.ATTR_PADDING_BOTTOM -> paddingBottom = value
            else -> return false
        }
        return true
    }
}
