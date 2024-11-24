package com.dynamic.otter.expression.analyze

class OTMap() : OTValue() {
    private var value: Any? = null

    constructor(value: Any?) : this() {
        this.value = value
    }

    override fun getValue(): Any? {
        return value
    }
}