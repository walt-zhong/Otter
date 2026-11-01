package com.dynamic.otter.nav

import com.dynamic.otter.template.json.TemplateParseException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PageRouteParserTest {
    @Test
    fun parsesRouteWithOptionalData() {
        val table = PageRouteParser.parse(
            """
            {
              "start": "home",
              "pages": {
                "home": {
                  "template": "templates/stack/home.json",
                  "data": "templates/stack/mock-data/home.json"
                },
                "detail": {
                  "template": "templates/stack/detail.json"
                }
              }
            }
            """.trimIndent()
        )

        assertEquals("home", table.start)
        assertEquals(2, table.pages.size)
        assertEquals("templates/stack/home.json", table.pages.getValue("home").template)
        assertEquals("templates/stack/mock-data/home.json", table.pages.getValue("home").data)
        assertEquals("templates/stack/detail.json", table.pages.getValue("detail").template)
        assertNull(table.pages.getValue("detail").data)
    }

    @Test
    fun rejectsMissingStart() {
        assertFails("$ 缺少 start") {
            PageRouteParser.parse(
                """
                {
                  "pages": {
                    "home": { "template": "templates/stack/home.json" }
                  }
                }
                """.trimIndent()
            )
        }
    }

    @Test
    fun rejectsMissingPages() {
        assertFails("$ 缺少 pages") {
            PageRouteParser.parse(
                """
                { "start": "home" }
                """.trimIndent()
            )
        }
    }

    @Test
    fun rejectsMissingTemplate() {
        assertFails("$.pages.home 缺少 template") {
            PageRouteParser.parse(
                """
                {
                  "start": "home",
                  "pages": {
                    "home": { "data": "templates/stack/mock-data/home.json" }
                  }
                }
                """.trimIndent()
            )
        }
    }

    @Test
    fun rejectsEmptyPages() {
        assertFails("$.pages 不能是空对象") {
            PageRouteParser.parse(
                """
                { "start": "home", "pages": {} }
                """.trimIndent()
            )
        }
    }

    @Test
    fun rejectsEmptyTemplate() {
        assertFails("$.pages.home.template 不能是空字符串") {
            PageRouteParser.parse(
                """
                {
                  "start": "home",
                  "pages": {
                    "home": { "template": "" }
                  }
                }
                """.trimIndent()
            )
        }
    }

    @Test
    fun rejectsIllegalPageName() {
        assertFails("$.pages 的页面名「1ab」必须是字母或下划线开头的标识符") {
            PageRouteParser.parse(
                """
                {
                  "start": "home",
                  "pages": {
                    "home": { "template": "templates/stack/home.json" },
                    "1ab": { "template": "templates/stack/detail.json" }
                  }
                }
                """.trimIndent()
            )
        }
    }

    @Test
    fun rejectsIllegalStartName() {
        assertFails("$.start「1ab」必须是字母或下划线开头的标识符") {
            PageRouteParser.parse(
                """
                {
                  "start": "1ab",
                  "pages": {
                    "home": { "template": "templates/stack/home.json" }
                  }
                }
                """.trimIndent()
            )
        }
    }

    @Test
    fun rejectsStartMissingFromPages() {
        assertFails("$.start 引用了不存在的页面 home") {
            PageRouteParser.parse(
                """
                {
                  "start": "home",
                  "pages": {
                    "detail": { "template": "templates/stack/detail.json" }
                  }
                }
                """.trimIndent()
            )
        }
    }

    @Test
    fun rejectsUnknownRootField() {
        assertFails("$.version 不是这里能写的字段") {
            PageRouteParser.parse(
                """
                {
                  "start": "home",
                  "version": 1,
                  "pages": {
                    "home": { "template": "templates/stack/home.json" }
                  }
                }
                """.trimIndent()
            )
        }
    }

    @Test
    fun rejectsUnknownPageField() {
        assertFails("$.pages.home.animation 不是这里能写的字段") {
            PageRouteParser.parse(
                """
                {
                  "start": "home",
                  "pages": {
                    "home": { "template": "templates/stack/home.json", "animation": "fade" }
                  }
                }
                """.trimIndent()
            )
        }
    }

    @Test
    fun rejectsMalformedRouteJson() {
        assertFailsPrefix("路由不是合法 JSON：") {
            PageRouteParser.parse("{")
        }
    }

    @Test
    fun rejectsTemplateThatIsNotAString() {
        assertFails("$.pages.home.template 必须是字符串") {
            PageRouteParser.parse(
                """
                {
                  "start": "home",
                  "pages": {
                    "home": { "template": 1 }
                  }
                }
                """.trimIndent()
            )
        }
    }

    @Test
    fun rejectsRouteThatIsNotAnObject() {
        assertFails("路由必须是 JSON 对象") {
            PageRouteParser.parse("null")
        }
        assertFailsPrefix("路由不是合法 JSON：") {
            PageRouteParser.parse("[]")
        }
    }

    private fun assertFails(message: String, block: () -> Unit) {
        try {
            block()
        } catch (error: TemplateParseException) {
            assertEquals(message, error.message)
            return
        }
        throw AssertionError("期望抛出 TemplateParseException：$message")
    }

    private fun assertFailsPrefix(prefix: String, block: () -> Unit) {
        try {
            block()
        } catch (error: TemplateParseException) {
            assertTrue(error.message?.startsWith(prefix) == true)
            return
        }
        throw AssertionError("期望抛出 TemplateParseException：$prefix")
    }
}
