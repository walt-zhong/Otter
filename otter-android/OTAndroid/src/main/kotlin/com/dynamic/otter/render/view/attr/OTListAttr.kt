package com.dynamic.otter.render.view.attr

import com.alibaba.fastjson.JSONArray
import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.expression.ExpressionWrapper
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.render.utils.FunctionExt.isExp

class OTListAttr : ViewAttr() {
    var data: String? = null
    var liveData: JSONArray? = null
    var listDirection: String? = null
    var itemPadding: String? = null

    override fun applyOwn(name: String, raw: String, scope: TemplateContext) {
        when (name) {
            TemplateKey.ATTR_DATA -> bindData(raw, scope)
            TemplateKey.ATTR_LIST_DIRECTION -> listDirection = raw.extractExpValue(scope.data)
            TemplateKey.ATTR_ITEM_PADDING -> itemPadding = raw.extractExpValue(scope.data)
        }
    }

    private fun bindData(raw: String, scope: TemplateContext) {
        val resolved = if (raw.isExp()) {
            ExpressionWrapper.instance.getResult(raw, scope.data)
        } else {
            null
        }
        if (resolved is JSONArray) {
            liveData = resolved
            data = resolved.toJSONString()
        } else {
            liveData = null
            data = raw.extractExpValue(scope.data)
        }
    }

    companion object {
        fun create(attrs: Map<String, String>, scope: TemplateContext): ViewAttr {
            return OTListAttr().bind(attrs, scope)
        }
    }
}
