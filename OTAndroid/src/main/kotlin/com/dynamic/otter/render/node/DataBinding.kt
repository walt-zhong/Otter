package com.dynamic.otter.render.node

import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.utils.toJson

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

    fun replaceEvents(events: Map<String, JSONObject>) {
        mEventMap = events.toMutableMap()
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