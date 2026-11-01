package com.dynamic.otter

import android.content.Context
import com.alibaba.fastjson.JSONObject

class ExpansionCenter {
    internal var extensionSize: ExtensionSize? = null
    internal var pageOpener: PageOpener? = null
    private val hostActions = mutableMapOf<String, HostAction>()

    interface ExtensionSize {
        fun create(value: String): Float?
        fun convert(value: Float): Float?
    }

    fun interface PageOpener {
        fun open(context: Context, page: String)
    }

    fun interface HostAction {
        fun handle(context: Context, params: JSONObject?)
    }

    fun interface ItemClick {
        fun onItemClick(item: Map<String, String>)
    }

    var itemClick: ItemClick? = null

    fun registerExtensionSize(extensionSize: ExtensionSize): ExpansionCenter {
        this.extensionSize = extensionSize
        return this
    }

    fun registerPageOpener(pageOpener: PageOpener): ExpansionCenter {
        this.pageOpener = pageOpener
        return this
    }

    fun registerHostAction(name: String, action: HostAction): ExpansionCenter {
        hostActions[name] = action
        return this
    }

    fun dispatchHost(context: Context, name: String, params: JSONObject?): Boolean {
        val action = hostActions[name] ?: return false
        action.handle(context, params)
        return true
    }

    companion object{
        val instance by lazy {
            ExpansionCenter()
        }
    }
}