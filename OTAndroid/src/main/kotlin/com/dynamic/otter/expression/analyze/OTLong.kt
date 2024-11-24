package com.dynamic.otter.expression.analyze

class OTLong() : OTValue() {
    private var value: Long? = null

    constructor(value: Long) : this() {
        this.value = value
    }

    fun getLong(): Long? {
        return value
    }

    override fun getValue(): Any? {
        return value
    }
}