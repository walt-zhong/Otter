package com.dynamic.otter.utils

import org.junit.Assert.assertEquals
import org.junit.Test

class ScreenAdaptTest {
    @Test
    fun designWidthStaysAtOne() {
        assertEquals(1f, ScreenAdapt.scaleFor(375f), 0.001f)
    }

    @Test
    fun commonPhoneScalesWithWindowWidth() {
        assertEquals(360f / 375f, ScreenAdapt.scaleFor(360f), 0.001f)
        assertEquals(411f / 375f, ScreenAdapt.scaleFor(411f), 0.001f)
    }

    @Test
    fun narrowWindowDoesNotShrinkWithoutLimit() {
        assertEquals(0.88f, ScreenAdapt.scaleFor(280f), 0.001f)
    }

    @Test
    fun tabletStopsAtLargePhoneScale() {
        assertEquals(480f / 375f, ScreenAdapt.scaleFor(800f), 0.001f)
        assertEquals(480f / 375f, ScreenAdapt.scaleFor(480f), 0.001f)
    }

    @Test
    fun missingWidthDoesNotScale() {
        assertEquals(1f, ScreenAdapt.scaleFor(0f), 0.001f)
    }
}
