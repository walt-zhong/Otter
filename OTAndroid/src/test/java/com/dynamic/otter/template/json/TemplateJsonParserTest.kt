package com.dynamic.otter.template.json

import com.dynamic.otter.data.TemplateKey
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class TemplateJsonParserTest {
    @Test
    fun parsesSizeColorGradientAndEvents() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "column",
                "id": "root",
                "layout": {
                  "width": "fill",
                  "height": "wrap",
                  "padding": { "start": 8, "top": 4 },
                  "justify": "spaceBetween",
                  "align": "start"
                },
                "style": {
                  "background": { "direction": "bottom", "colors": ["#112233", "#ffffff"] },
                  "radius": { "topStart": 12 },
                  "border": { "color": "#ff0000", "width": 1 }
                },
                "children": [
                  {
                    "type": "text",
                    "id": "title",
                    "text": "${'$'}title",
                    "layout": { "width": 100, "height": 20 },
                    "style": { "color": "transparent", "fontSize": 16, "align": "center" },
                    "onClick": ["rename"]
                  }
                ]
              },
              "events": {
                "rename": { "action": "setText", "target": "title", "value": "已改" }
              }
            }
            """.trimIndent()
        )

        val root = parsed.root
        assertEquals(TemplateKey.COLUMN, root.viewName)
        assertEquals("match_parent", root.attrs[TemplateKey.ATTR_WIDTH])
        assertEquals("wrap_content", root.attrs[TemplateKey.ATTR_HEIGHT])
        assertEquals("8", root.attrs[TemplateKey.ATTR_PADDING_START])
        assertEquals("4", root.attrs[TemplateKey.ATTR_PADDING_TOP])
        assertEquals("space-between", root.attrs[TemplateKey.FLEXBOX_ATTR_JUSTIFY_CONTENT])
        assertEquals("start", root.attrs[TemplateKey.FLEXBOX_ATTR_ALIGN_ITEMS])
        assertEquals(
            "linear-gradient(to bottom, #112233, #ffffff)",
            root.attrs[TemplateKey.ATTR_BACKGROUND]
        )
        assertEquals("12", root.attrs[TemplateKey.ATTR_LEFT_TOP_RADIUS])
        assertEquals(TemplateKey.TEXT, root.children.single().viewName)
        assertEquals("rename", root.children.single().attrs[TemplateKey.ATTR_ONCLICK])
        assertEquals("title", parsed.events.getValue("rename").getJSONObject("params").getString("id"))
    }

    @Test
    fun listItemIsSeparateAndLottieGetsDefaults() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "list",
                "id": "feed",
                "data": "${'$'}items",
                "layout": { "width": "fill", "height": 120 },
                "item": {
                  "type": "lottie",
                  "src": "assets:animation/lottie-sunny",
                  "layout": { "width": 24, "height": 24 }
                }
              }
            }
            """.trimIndent()
        )

        assertEquals(TemplateKey.OT_LIST, parsed.root.viewName)
        assertTrue(parsed.root.children.isEmpty())
        assertEquals("vertical", parsed.root.attrs[TemplateKey.ATTR_LIST_DIRECTION])
        val item = parsed.root.item!!
        assertEquals(TemplateKey.ANIMATION, item.viewName)
        assertEquals("infinite", item.attrs[TemplateKey.ATTR_ANI_REPEAT_COUNT])
        assertEquals("restart", item.attrs[TemplateKey.ATTR_ANI_REPEAT_MODE])
        assertEquals("true", item.attrs[TemplateKey.ATTR_ANI_AUTO_PLAY])
        assertNull(parsed.root.item?.children?.firstOrNull())
    }

    @Test
    fun progressTrackAndBarUseEngineColorFields() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "progress",
                "layout": { "width": 80, "height": 7 },
                "from": "${'$'}start",
                "to": 0.8,
                "animate": false,
                "style": { "track": "${'$'}strokeColor", "bar": "#FFD700" }
              }
            }
            """.trimIndent()
        )

        assertEquals("\$strokeColor", parsed.root.attrs[TemplateKey.ATTR_STROKE_COLOR])
        assertEquals("#FFD700", parsed.root.attrs[TemplateKey.ATTR_TRAIL_COLOR])
        assertEquals("\$start", parsed.root.attrs[TemplateKey.ATTR_VALUE_MIN])
        assertEquals("0.8", parsed.root.attrs[TemplateKey.ATTR_VALUE_MAX])
        assertEquals("false", parsed.root.attrs[TemplateKey.ATTR_ANIMATE_ENABLE])
    }

    @Test
    fun rejectsUnknownFieldMissingEventAndMissingTarget() {
        assertFails("$.layout.children 不是这里能写的字段") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 }, "children": [] } }
                """.trimIndent()
            )
        }
        assertFails("onClick 引用了不存在的事件 missing") {
            TemplateJsonParser.parse(
                """
                {
                  "layout": {
                    "type": "text",
                    "id": "label",
                    "text": "Hi",
                    "layout": { "width": 1, "height": 1 },
                    "onClick": ["missing"]
                  }
                }
                """.trimIndent()
            )
        }
        assertFails("事件 rename 的 target「gone」在模版中不存在") {
            TemplateJsonParser.parse(
                """
                {
                  "layout": {
                    "type": "text",
                    "id": "label",
                    "text": "Hi",
                    "layout": { "width": 1, "height": 1 }
                  },
                  "events": {
                    "rename": { "action": "setText", "target": "gone", "value": "x" }
                  }
                }
                """.trimIndent()
            )
        }
    }

    @Test
    fun demoTemplatesParse() {
        val root = listOf(
            File("../Demo/src/main/assets/templates"),
            File("Demo/src/main/assets/templates")
        ).firstOrNull { it.isDirectory }
            ?: throw AssertionError("找不到 Demo 模版目录")
        listOf(
            "layout-demo/layout.json",
            "text-demo/layout_text.json",
            "list-demo/list.json",
            "progress-demo/progress.json",
            "animation-demo/animation.json",
            "scaffold-demo/scaffold.json",
            "weather-card-demo/weather-card.json"
        ).forEach { relative ->
            val file = File(root, relative)
            assertTrue("缺少 ${file.path}", file.isFile)
            TemplateJsonParser.parse(file.readText())
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
}
