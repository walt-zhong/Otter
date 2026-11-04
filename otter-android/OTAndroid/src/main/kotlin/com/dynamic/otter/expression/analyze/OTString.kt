package com.dynamic.otter.expression.analyze

class OTString() : OTValue() {
    private var value: String? = null

    constructor(value: String) : this() {
        this.value = value
    }

    fun getString(): String? {
        return value
    }

    override fun getValue(): Any? {
        return value
    }
}