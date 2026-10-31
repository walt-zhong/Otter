package com.dynamic.otter

import android.content.Context

class ExpansionCenter {
    internal var extensionSize: ExtensionSize? = null
    internal var pageOpener: PageOpener? = null

    interface ExtensionSize {
        fun create(value: String): Float?
        fun convert(value: Float): Float?
    }

    fun interface PageOpener {
        fun open(context: Context, page: String)
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

    companion object{
        val instance by lazy {
            ExpansionCenter()
        }
    }
}