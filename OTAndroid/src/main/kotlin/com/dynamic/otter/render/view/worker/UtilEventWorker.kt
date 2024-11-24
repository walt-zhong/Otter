package com.dynamic.otter.render.view.worker

import android.view.View
import android.widget.Toast
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue

class UtilEventWorker private constructor() : IEventWorker {
    override fun handleEvent(clickedView: View, paramJsonObj: JSONObject, itemData: JSONObject?) {
        val funMarker = paramJsonObj["fun"]
        when (funMarker) {
            "showToast" -> {
                val value = if(itemData == null){
                    paramJsonObj["info"].toString().extractExpValue()
                }else{
                    paramJsonObj["info"].toString().extractExpValue(itemData)
                }

                Toast.makeText(clickedView.context, value, Toast.LENGTH_SHORT)
                    .show()
            }
        }
    }

    companion object {
        val instance by lazy {
            UtilEventWorker()
        }
    }
}