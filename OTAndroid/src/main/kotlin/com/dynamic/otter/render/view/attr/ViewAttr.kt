package com.dynamic.otter.render.view.attr

import android.view.View
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.template.OTFlexBox
import org.w3c.dom.NamedNodeMap

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
    protected open fun parseAttrs(attrsMap: NamedNodeMap): ViewAttr {
        for (i in 0 until attrsMap.length) {
            val attrName = attrsMap.item(i).nodeName
            val attrValue = attrsMap.item(i).nodeValue.extractExpValue()
            when (attrName) {
                TemplateKey.ATTR_ID -> {
                    val viewId = View.generateViewId()
                    id = viewId
                    TemplateKey.RMap[attrValue] = viewId
                }

                TemplateKey.ATTR_WIDTH -> {
                    width = attrValue
                }

                TemplateKey.ATTR_HEIGHT -> {
                    height = attrValue
                }

                TemplateKey.ATTR_BACKGROUND -> {
                    background = attrValue
                }

                TemplateKey.ATTR_ONCLICK -> {
                    onClick = attrValue
                }

                TemplateKey.ATTR_RADIUS -> {
                    radius = attrValue
                }

                TemplateKey.ATTR_LEFT_TOP_RADIUS -> {
                    leftTopRadius = attrValue
                }

                TemplateKey.ATTR_LEFT_BOTTOM_RADIUS -> {
                    leftBottomRadius = attrValue
                }

                TemplateKey.ATTR_RIGHT_TOP_RADIUS -> {
                    rightTopRadius = attrValue
                }

                TemplateKey.ATTR_RIGHT_BOTTOM_RADIUS -> {
                    rightBottomRadius = attrValue
                }

                TemplateKey.ATTR_BORDER_COLOR -> {
                    borderColor = attrValue
                }

                TemplateKey.ATTR_BORDER_WIDTH -> {
                    borderWidth = attrValue
                }

                TemplateKey.ATTR_PADDING -> {
                    padding = attrValue
                }

                TemplateKey.ATTR_PADDING_START -> {
                    paddingStart = attrValue
                }

                TemplateKey.ATTR_PADDING_END -> {
                    paddingEnd = attrValue
                }

                TemplateKey.ATTR_PADDING_TOP -> {
                    paddingTop = attrValue
                }

                TemplateKey.ATTR_PADDING_BOTTOM -> {
                    paddingBottom = attrValue
                }
            }
        }

        return this
    }
}