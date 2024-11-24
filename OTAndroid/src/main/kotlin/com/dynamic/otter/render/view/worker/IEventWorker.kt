package com.dynamic.otter.render.view.worker

import android.view.View
import com.alibaba.fastjson.JSONObject

interface IEventWorker {
    fun handleEvent(clickedView: View, paramJsonObj: JSONObject, itemData: JSONObject? = null)
}