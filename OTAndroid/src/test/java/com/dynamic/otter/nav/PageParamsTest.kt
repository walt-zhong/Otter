package com.dynamic.otter.nav

import com.alibaba.fastjson.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PageParamsTest {
    @Test
    fun mergeOverwritesSameKeys() {
        val baseNested = JSONObject().apply {
            put("a", 1)
            put("b", 2)
        }
        val overlayNested = JSONObject().apply {
            put("b", 9)
        }
        val base = JSONObject().apply {
            put("name", "旧")
            put("meta", baseNested)
        }
        val overlay = JSONObject().apply {
            put("name", "新")
            put("meta", overlayNested)
            put("extra", "加上")
        }

        val merged = PageParams.merge(base, overlay)

        assertEquals("新", merged!!.get("name"))
        assertEquals("加上", merged.get("extra"))
        val meta = merged.getJSONObject("meta")
        assertEquals(9, meta.get("b"))
        assertTrue(!meta.containsKey("a"))
        assertEquals("旧", base.get("name"))
        assertEquals(1, baseNested.get("a"))
        assertEquals(2, baseNested.get("b"))
        assertEquals(9, overlayNested.get("b"))
        assertTrue(merged !== base)
        assertTrue(merged !== overlay)
    }

    @Test
    fun falseAndZeroOverwriteOldValues() {
        val base = JSONObject().apply {
            put("ok", true)
            put("count", 1)
            put("name", "留")
        }
        val overlay = JSONObject().apply {
            put("ok", false)
            put("count", 0)
        }

        val merged = PageParams.merge(base, overlay)

        assertEquals(false, merged!!.get("ok"))
        assertEquals(0, merged.get("count"))
        assertEquals("留", merged.get("name"))
        assertEquals(true, base.get("ok"))
        assertEquals(1, base.get("count"))
        assertTrue(merged !== base)
        assertTrue(merged !== overlay)
    }

    @Test
    fun nullBaseReturnsCopyOfOverlay() {
        val overlay = JSONObject().apply {
            put("city", "上海")
            put("ok", false)
            put("count", 0)
        }

        val merged = PageParams.merge(null, overlay)

        assertEquals(overlay, merged)
        assertEquals("上海", merged!!.get("city"))
        assertEquals(false, merged.get("ok"))
        assertEquals(0, merged.get("count"))
        assertTrue(merged !== overlay)
        merged["city"] = "改了"
        assertEquals("上海", overlay.get("city"))
    }

    @Test
    fun emptyOverlayLeavesBaseUnchanged() {
        val base = JSONObject().apply {
            put("city", "北京")
            put("ok", false)
            put("count", 0)
        }
        val overlay = JSONObject()

        val merged = PageParams.merge(base, overlay)
        val fromNull = PageParams.merge(base, null)

        assertEquals(base, merged)
        assertEquals(base, fromNull)
        assertTrue(merged !== base)
        assertTrue(merged !== overlay)
        assertTrue(fromNull !== base)
        merged!!["city"] = "改了"
        assertEquals("北京", base.get("city"))
        assertEquals(false, base.get("ok"))
        assertEquals(0, base.get("count"))
        assertEquals("北京", fromNull!!.get("city"))
    }

    @Test
    fun evaluateKeepsPlainValuesAndWritesResolveResult() {
        val raw = JSONObject().apply {
            put("label", "北京")
            put("city", "\$city")
            put("count", 2)
            put("ok", true)
            put("n", "\$n")
            put("flag", "\$flag")
        }
        val seen = mutableListOf<String>()

        val result = PageParams.evaluate(raw) { expression ->
            seen += expression
            when (expression) {
                "\$city" -> "上海"
                "\$n" -> 0
                "\$flag" -> false
                else -> error("unexpected $expression")
            }
        }

        assertEquals(setOf("\$city", "\$n", "\$flag"), seen.toSet())
        assertEquals(3, seen.size)
        assertEquals("北京", result.get("label"))
        assertEquals("上海", result.get("city"))
        assertEquals(2, result.get("count"))
        assertEquals(true, result.get("ok"))
        assertEquals(0, result.get("n"))
        assertEquals(false, result.get("flag"))
        assertEquals(raw.size, result.size)
        assertEquals("北京", raw.get("label"))
        assertEquals("\$city", raw.get("city"))
        assertTrue(result !== raw)
    }

    @Test
    fun evaluateKeepsDollarStringWhenResolveReturnsNull() {
        val marker = JSONObject().apply { put("id", 1) }
        val raw = JSONObject().apply {
            put("city", "\$city")
            put("item", "\$item")
            put("label", "原文")
        }

        val result = PageParams.evaluate(raw) { expression ->
            when (expression) {
                "\$city" -> null
                "\$item" -> marker
                else -> error("unexpected $expression")
            }
        }

        assertEquals("\$city", result.get("city"))
        assertTrue(result.get("item") === marker)
        assertEquals("原文", result.get("label"))
        assertEquals("\$city", raw.get("city"))
        assertEquals("\$item", raw.get("item"))
        assertTrue(result !== raw)
    }

    @Test
    fun evaluateCopiesNestedTemplateValues() {
        val nested = JSONObject().apply { put("name", "\$city") }
        val raw = JSONObject().apply {
            put("meta", nested)
            put("tags", com.alibaba.fastjson.JSONArray().apply { add("\$city") })
        }

        val result = PageParams.evaluate(raw) { "上海" }

        val meta = result.getJSONObject("meta")
        assertEquals("上海", meta.get("name"))
        assertEquals("上海", result.getJSONArray("tags").get(0))
        assertEquals("\$city", nested.get("name"))
        assertTrue(meta !== nested)
    }

    @Test
    fun matchesComparesOnlyOverlayKeys() {
        val lines = com.alibaba.fastjson.JSONArray().apply { add("一句") }
        val data = JSONObject().apply {
            put("name", "窗边")
            put("count", 1)
            put("ok", false)
            put("lines", lines)
        }
        val same = JSONObject().apply {
            put("name", "窗边")
            put("count", 1.0)
            put("ok", false)
        }
        val renamed = JSONObject().apply { put("name", "今日日晒") }
        val empty = JSONObject()

        assertTrue(PageParams.matches(data, same))
        assertTrue(PageParams.matches(data, empty))
        assertTrue(PageParams.matches(data, null))
        assertTrue(!PageParams.matches(data, renamed))
        assertTrue(!PageParams.matches(null, same))
    }
}
