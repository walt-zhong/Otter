package com.dynamic.otter.render.node

import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.utils.toJson
import org.w3c.dom.Node
import org.w3c.dom.NodeList

class DataBinding {
    // 通过方法ID 将事件的描述json保存在mEventMap中，事件包括点击事件，长按事件
    private var mEventMap: MutableMap<String, JSONObject> = mutableMapOf()
    private var mData: JSONObject? = null

    fun getEventMap(): MutableMap<String, JSONObject> {
        return mEventMap
    }

    fun getData(): JSONObject? {
        return mData
    }

    fun parseEvents(nodeList: NodeList) {
        for (i in 0 until nodeList.length) {
            val itemNode = nodeList.item(i)
            for (j in 0 until itemNode.childNodes.length) {
                val childItemNode = itemNode.childNodes.item(j)
                if (childItemNode.nodeType == Node.ELEMENT_NODE
                    && childItemNode.nodeName == "Event"
                ) {
                    val attributesMap = childItemNode.attributes
                    if (attributesMap != null) {
                        val nodeValue = attributesMap
                            .getNamedItem(TemplateKey.ATTR_FUN_ID)?.nodeValue
                            ?: throw IllegalArgumentException("event id must not be empty!!!")
                        if (nodeValue.isNotEmpty()) {
                            for (k in 0 until childItemNode.childNodes.length) {
                                val eventItemNode = childItemNode.childNodes.item(k)
                                if (eventItemNode.nodeType == Node.TEXT_NODE) {
                                    mEventMap[nodeValue] =
                                        eventItemNode.textContent.toJson()
                                }
                            }
                        } else {
                            throw IllegalArgumentException("event id attr must have value!!!")
                        }
                    }
                }
            }
        }
    }

    fun buildTemplateData(dataJson: String) {
        this.mData = dataJson.toJson()
    }


    companion object {
        val instance by lazy {
            DataBinding()
        }
    }
}