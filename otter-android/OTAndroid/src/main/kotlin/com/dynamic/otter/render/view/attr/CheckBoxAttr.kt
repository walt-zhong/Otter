package com.dynamic.otter.render.view.attr

import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue

class CheckBoxAttr : ViewAttr() {
    var text = ""
    var checked = false
    var tint = "#1F6F6A"
    var textColor = "#1F1A17"
    var textSize = "14px"
    var checkedSource = "false"

    override fun applyOwn(name: String, raw: String, scope: TemplateContext) {
        val value = raw.extractExpValue(scope.data)
        when (name) {
            TemplateKey.ATTR_TEXT -> text = value
            TemplateKey.ATTR_CHECKED -> {
                checkedSource = value
                checked = value == "true"
            }
            TemplateKey.ATTR_TINT -> tint = value
            TemplateKey.ATTR_TEXT_COLOR -> textColor = value
            TemplateKey.ATTR_TEXT_SIZE -> textSize = value
        }
    }

    companion object {
        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            return CheckBoxAttr().bind(attrs, scope)
        }
    }
}
