package com.dynamic.otter.expression.analyze

class OTFloat() : OTValue() {
    private var value: Float? = null

    constructor(value: Float) : this() {
        this.value = value
    }

    fun getFloat(): Float? {
        return value
    }

    override fun getValue(): Any? {
        return value
    }
}