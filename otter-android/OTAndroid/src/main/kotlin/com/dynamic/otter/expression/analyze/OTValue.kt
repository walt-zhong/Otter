package com.dynamic.otter.expression.analyze

abstract class OTValue {

    fun <T : OTValue?> cast(clazz: Class<T>): T {
        return if (clazz.isInstance(this)) {
            this as T
        } else {
            throw RuntimeException("expected: " + clazz.simpleName + ", actual: " + javaClass.simpleName)
        }
    }

    abstract fun getValue(): Any?
}