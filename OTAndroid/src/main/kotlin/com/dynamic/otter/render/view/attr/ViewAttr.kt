package com.dynamic.otter.render.view.attr

import android.view.View
import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.template.OTFlexBox

open class ViewAttr {
    var id: Int = 0
    var idName: String? = null
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
    var glassStyle: String? = null
    var glassTint: String? = null
    var glassInteractive: String? = null
    var padding: String? = null
    var paddingStart: String? = null
    var paddingEnd: String? = null
    var paddingTop: String? = null
    var paddingBottom: String? = null
    var margin: String? = null
    var marginStart: String? = null
    var marginEnd: String? = null
    var marginTop: String? = null
    var marginBottom: String? = null
    var visible: String? = null
    var onChange: String? = null
    var minWidth: String? = null
    var minHeight: String? = null
    var maxWidth: String? = null
    var maxHeight: String? = null
    var aspectRatio: String? = null
    var alignSelf: String? = null
    var flexGrow: Float = 0f
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
                idName = value
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
            TemplateKey.ATTR_GLASS_STYLE -> glassStyle = value
            TemplateKey.ATTR_GLASS_TINT -> glassTint = value
            TemplateKey.ATTR_GLASS_INTERACTIVE -> glassInteractive = value
            TemplateKey.ATTR_PADDING -> padding = value
            TemplateKey.ATTR_PADDING_START -> paddingStart = value
            TemplateKey.ATTR_PADDING_END -> paddingEnd = value
            TemplateKey.ATTR_PADDING_TOP -> paddingTop = value
            TemplateKey.ATTR_PADDING_BOTTOM -> paddingBottom = value
            TemplateKey.ATTR_MARGIN -> margin = value
            TemplateKey.ATTR_MARGIN_START -> marginStart = value
            TemplateKey.ATTR_MARGIN_END -> marginEnd = value
            TemplateKey.ATTR_MARGIN_TOP -> marginTop = value
            TemplateKey.ATTR_MARGIN_BOTTOM -> marginBottom = value
            TemplateKey.ATTR_VISIBLE -> visible = value
            TemplateKey.ATTR_ONCHANGE -> onChange = raw
            TemplateKey.ATTR_MIN_WIDTH -> minWidth = value
            TemplateKey.ATTR_MIN_HEIGHT -> minHeight = value
            TemplateKey.ATTR_MAX_WIDTH -> maxWidth = value
            TemplateKey.ATTR_MAX_HEIGHT -> maxHeight = value
            TemplateKey.ATTR_ASPECT_RATIO -> aspectRatio = value
            TemplateKey.ATTR_ALIGN_SELF -> alignSelf = raw
            TemplateKey.ATTR_FLEX_GROW -> flexGrow = value.toFloatOrNull() ?: 0f
            else -> return false
        }
        return true
    }
}
