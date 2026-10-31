package com.dynamic.otter.render.view.attr

import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue

class InputAttr : ViewAttr() {
    var text = ""
    var hint = ""
    var hintColor = "#8A8178"
    var textColor = "#1F1A17"
    var textSize = "14px"
    var textAlign: String? = null
    var inputType = "text"
    var maxLength: String? = null

    override fun applyOwn(name: String, raw: String, scope: TemplateContext) {
        val value = raw.extractExpValue(scope.data)
        when (name) {
            TemplateKey.ATTR_TEXT -> text = value
            TemplateKey.ATTR_HINT -> hint = value
            TemplateKey.ATTR_HINT_COLOR -> hintColor = value
            TemplateKey.ATTR_TEXT_COLOR -> textColor = value
            TemplateKey.ATTR_TEXT_SIZE -> textSize = value
            TemplateKey.ATTR_TEXT_ALIGN -> textAlign = value
            TemplateKey.ATTR_INPUT_TYPE -> inputType = value
            TemplateKey.ATTR_MAX_LENGTH -> maxLength = value
        }
    }

    companion object {
        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            return InputAttr().bind(attrs, scope)
        }
    }
}
