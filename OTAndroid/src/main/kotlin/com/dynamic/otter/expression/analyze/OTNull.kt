package com.dynamic.otter.expression.analyze

class OTNull : OTValue() {

    override fun getValue(): Any? {
        return null
    }
}