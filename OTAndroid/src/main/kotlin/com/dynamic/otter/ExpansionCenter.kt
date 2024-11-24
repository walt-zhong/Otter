package com.dynamic.otter

class ExpansionCenter {
    internal var extensionSize:ExtensionSize? = null

    interface ExtensionSize{
        fun create(value:String):Float?
        fun convert(value:Float):Float?
    }

    fun registerExtensionSize(extensionSize:ExtensionSize):ExpansionCenter{
        this.extensionSize = extensionSize
        return this
    }

    companion object{
        val instance by lazy {
            ExpansionCenter()
        }
    }
}