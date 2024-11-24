package com.dynamic.otter.expression.analyze

class OTBool() : OTValue() {
    private var value: Boolean? = null

    constructor(value: Boolean) : this() {
        this.value = value
    }

    fun getBool(): Boolean? {
        return value
    }

    override fun getValue(): Any? {
        return value
    }
}