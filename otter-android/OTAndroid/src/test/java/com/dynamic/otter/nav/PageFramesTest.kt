package com.dynamic.otter.nav

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PageFramesTest {
    @Test
    fun popOnSingleFrameReturnsNullAndKeepsDepth() {
        val frames = PageFrames()
        frames.push("home")

        assertEquals(1, frames.depth)
        assertEquals("home", frames.top())
        assertNull(frames.pop())
        assertNull(frames.pop())
        assertEquals(1, frames.depth)
        assertEquals("home", frames.top())
    }

    @Test
    fun popReturnsPushedNameAndRestoresPreviousTop() {
        val frames = PageFrames()
        frames.push("home")
        frames.push("detail")

        assertEquals(2, frames.depth)
        assertEquals("detail", frames.top())
        assertEquals("detail", frames.pop())
        assertEquals(1, frames.depth)
        assertEquals("home", frames.top())
    }

    @Test
    fun popOnEmptyStackReturnsNull() {
        val frames = PageFrames()

        assertEquals(0, frames.depth)
        assertNull(frames.top())
        assertNull(frames.pop())
        assertEquals(0, frames.depth)
    }

    @Test
    fun clearReturnsRemainingNamesAndEmpties() {
        val frames = PageFrames()
        frames.push("home")
        frames.push("detail")

        assertEquals(listOf("home", "detail"), frames.clear())
        assertEquals(0, frames.depth)
        assertNull(frames.top())
        assertNull(frames.pop())
        assertTrue(frames.clear().isEmpty())
    }

    @Test
    fun dropRemovesTheOnlyNameAndPopStillRefusesASingleFrame() {
        val frames = PageFrames()
        frames.push("checkout")

        assertEquals("checkout", frames.drop())
        assertEquals(0, frames.depth)
        assertNull(frames.top())
        assertNull(frames.drop())

        frames.push("checkout")
        assertEquals(1, frames.depth)
        assertEquals("checkout", frames.top())
        assertNull(frames.pop())
        assertEquals("checkout", frames.top())
    }

    @Test
    fun dropThenPushReplacesTheTopWithoutKeepingItUnderneath() {
        val frames = PageFrames()
        frames.push("home")
        frames.push("checkout")

        assertEquals("checkout", frames.drop())
        frames.push("result")

        assertEquals(2, frames.depth)
        assertEquals("result", frames.top())
        assertEquals("result", frames.pop())
        assertEquals("home", frames.top())
        assertNull(frames.pop())
    }

    @Test
    fun popToMissingNameLeavesTheStackUntouched() {
        val frames = PageFrames()
        frames.push("home")
        frames.push("detail")

        assertNull(frames.popTo("missing"))
        assertEquals(2, frames.depth)
        assertEquals("detail", frames.top())
        assertEquals("detail", frames.pop())
        assertEquals("home", frames.top())
    }

    @Test
    fun popToCurrentTopReturnsEmptyAndDoesNotPop() {
        val frames = PageFrames()
        frames.push("home")
        frames.push("detail")

        assertEquals(emptyList<String>(), frames.popTo("detail"))
        assertEquals(2, frames.depth)
        assertEquals("detail", frames.top())
        assertNull(frames.popTo(""))
    }

    @Test
    fun popToRemovesNamesAboveTheNearestMatchFromTheTopDown() {
        val frames = PageFrames()
        frames.push("home")
        frames.push("list")
        frames.push("detail")
        frames.push("list")
        frames.push("pay")

        assertEquals(listOf("pay"), frames.popTo("list"))
        assertEquals(4, frames.depth)
        assertEquals("list", frames.top())
        assertEquals("list", frames.pop())
        assertEquals("detail", frames.top())
    }

    @Test
    fun popToDropsIntermediatesUntilTheTargetIncludingTheRoot() {
        val frames = PageFrames()
        frames.push("home")
        frames.push("list")
        frames.push("detail")
        frames.push("checkout")

        assertEquals(listOf("checkout", "detail", "list"), frames.popTo("home"))
        assertEquals(1, frames.depth)
        assertEquals("home", frames.top())
        assertNull(frames.pop())
        assertEquals("home", frames.top())
    }
}
