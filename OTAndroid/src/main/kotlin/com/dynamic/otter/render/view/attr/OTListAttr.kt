package com.dynamic.otter.render.view.attr

import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.template.OTFlexBox
import org.w3c.dom.NamedNodeMap

class OTListAttr : ViewAttr() {
    var data: String? = null
    var listDirection: String? = null
    var itemPadding:String? = null
    override fun parseAttrs(attrsMap: NamedNodeMap): ViewAttr {
        val columnListAttr = super.parseAttrs(attrsMap) as OTListAttr
        for (i in 0 until attrsMap.length) {
            val attrName = attrsMap.item(i).nodeName
            val attrValue = attrsMap.item(i).nodeValue.extractExpValue()
            when (attrName) {
                TemplateKey.ATTR_DATA -> columnListAttr.data = attrValue
                TemplateKey.ATTR_LIST_DIRECTION -> columnListAttr.listDirection = attrValue
                TemplateKey.ATTR_ITEM_PADDING->columnListAttr.itemPadding = attrValue
            }
        }
        flexbox = OTFlexBox.create(columnListAttr)
        return columnListAttr
    }

    companion object {
        fun create(attrMap: NamedNodeMap): ViewAttr {
            return OTListAttr().parseAttrs(attrMap)
        }
    }
}