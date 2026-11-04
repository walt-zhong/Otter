package com.dynamic.otter.nav

internal class PageFrames {
    private val names = mutableListOf<String>()

    val depth: Int
        get() = names.size

    fun push(name: String) {
        names.add(name)
    }

    fun pop(): String? {
        if (depth <= 1) {
            return null
        }
        return names.removeAt(names.lastIndex)
    }

    fun drop(): String? {
        if (names.isEmpty()) {
            return null
        }
        return names.removeAt(names.lastIndex)
    }

    fun popTo(name: String): List<String>? {
        val index = names.lastIndexOf(name)
        if (index < 0) {
            return null
        }
        val removed = mutableListOf<String>()
        while (names.lastIndex > index) {
            removed.add(names.removeAt(names.lastIndex))
        }
        return removed
    }

    fun top(): String? = names.lastOrNull()

    fun clear(): List<String> {
        val remaining = names.toList()
        names.clear()
        return remaining
    }
}
