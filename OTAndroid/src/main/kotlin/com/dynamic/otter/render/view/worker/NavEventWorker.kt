package com.dynamic.otter.render.view.worker

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.view.View
import android.widget.Toast
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.ExpansionCenter
import com.dynamic.otter.expression.ExpressionWrapper
import com.dynamic.otter.nav.PageParams
import com.dynamic.otter.nav.PageStack
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue

class NavEventWorker private constructor() : IEventWorker {
    override fun handleEvent(
        clickedView: View,
        paramJsonObj: JSONObject,
        itemData: JSONObject?,
        pageData: JSONObject?,
        rootView: View?,
        viewIds: Map<String, Int>
    ) {
        when (paramJsonObj["fun"]) {
            "back" -> {
                val stack = PageStack.find(clickedView.context)
                if (stack != null && stack.pop(paramJsonObj.getJSONObject("params"))) {
                    return
                }
                clickedView.context.findActivity()?.finish()
            }
            "open" -> openOrReplace(clickedView, paramJsonObj, itemData, pageData, replace = false)
            "replace" -> openOrReplace(clickedView, paramJsonObj, itemData, pageData, replace = true)
            "popTo" -> popTo(clickedView, paramJsonObj, itemData, pageData)
            "host" -> host(clickedView, paramJsonObj, itemData, pageData)
        }
    }

    private fun openOrReplace(
        clickedView: View,
        paramJsonObj: JSONObject,
        itemData: JSONObject?,
        pageData: JSONObject?,
        replace: Boolean
    ) {
        val scope = PageParams.merge(pageData, itemData)
        val page = paramJsonObj["page"].toString().extractExpValue(scope)
        val stack = PageStack.find(clickedView.context)
        if (stack != null) {
            if (page.isBlank() || page == "null") {
                toast(clickedView.context, CANNOT_OPEN)
                return
            }
            val params = paramJsonObj.getJSONObject("params")
            if (replace) {
                stack.replace(page, params, itemData, pageData)
            } else {
                stack.open(page, params, itemData, pageData)
            }
            return
        }
        val opener = ExpansionCenter.instance.pageOpener
        if (opener == null || page.isBlank() || page == "null") {
            toast(clickedView.context, CANNOT_OPEN)
            return
        }
        opener.open(clickedView.context, page)
    }

    private fun popTo(
        clickedView: View,
        paramJsonObj: JSONObject,
        itemData: JSONObject?,
        pageData: JSONObject?
    ) {
        val scope = PageParams.merge(pageData, itemData)
        val page = paramJsonObj["page"].toString().extractExpValue(scope)
        val stack = PageStack.find(clickedView.context)
        if (stack != null && page.isNotBlank() && page != "null" &&
            stack.popTo(page, paramJsonObj.getJSONObject("params"))
        ) {
            return
        }
        toast(clickedView.context, CANNOT_OPEN)
    }

    private fun host(
        clickedView: View,
        paramJsonObj: JSONObject,
        itemData: JSONObject?,
        pageData: JSONObject?
    ) {
        val scope = PageParams.merge(pageData, itemData)
        val name = paramJsonObj["name"].toString().extractExpValue(scope)
        if (name.isBlank() || name == "null") {
            toast(clickedView.context, CANNOT_USE)
            return
        }
        val params = paramJsonObj.getJSONObject("params")?.let { raw ->
            PageParams.evaluate(raw) { expression ->
                ExpressionWrapper.instance.getResult(expression, scope)
            }
        }
        if (!ExpansionCenter.instance.dispatchHost(clickedView.context, name, params)) {
            toast(clickedView.context, CANNOT_USE)
        }
    }

    private fun toast(context: Context, message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    private fun Context.findActivity(): Activity? {
        var current = this
        while (current is ContextWrapper) {
            if (current is Activity) {
                return current
            }
            current = current.baseContext
        }
        return null
    }

    companion object {
        private const val CANNOT_OPEN = "这个页面还打不开"
        private const val CANNOT_USE = "这个操作还不能用"

        val instance by lazy { NavEventWorker() }
    }
}
