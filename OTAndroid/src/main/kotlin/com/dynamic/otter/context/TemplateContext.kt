package com.dynamic.otter.context

import android.content.Context
import android.view.View
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.OTEngine
import com.dynamic.otter.render.node.OTNode
import com.dynamic.otter.render.node.VDomNode
import com.dynamic.otter.utils.toJson

class TemplateContext private constructor(
    val context: Context,
    val template: OTEngine.OTTemplate
) {
    var rootView: View? = null

    var rootNode: OTNode? = null

    var vDomNode: VDomNode? = null

    var data: JSONObject? = null

    var events: Map<String, JSONObject> = emptyMap()

    val viewIds: MutableMap<String, Int> = mutableMapOf()

    fun setData(dataJson: String) {
        data = dataJson.toJson()
    }

    fun release() {
        rootNode?.release()
        rootNode = null
        rootView = null
        vDomNode = null
        data = null
        events = emptyMap()
        viewIds.clear()
    }

    companion object {
        fun create(template: OTEngine.OTTemplate): TemplateContext {
            return TemplateContext(template.context, template)
        }
    }
}
