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
                  "grow": 1,
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
        assertEquals("1", root.attrs[TemplateKey.ATTR_FLEX_GROW])
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
    fun progressBarAcceptsGradient() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "progress",
                "layout": { "width": 80, "height": 7 },
                "from": 0,
                "to": 0.5,
                "style": {
                  "track": "#245566",
                  "bar": { "direction": "right", "colors": ["#7EB6C9", "#F2C14E", "#E07A3D"] }
                }
              }
            }
            """.trimIndent()
        )

        assertEquals("#245566", parsed.root.attrs[TemplateKey.ATTR_STROKE_COLOR])
        assertEquals(
            "linear-gradient(to right, #7EB6C9, #F2C14E, #E07A3D)",
            parsed.root.attrs[TemplateKey.ATTR_TRAIL_COLOR]
        )
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
    fun backEventClosesThePage() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "text",
                "text": "返回",
                "layout": { "width": 40, "height": 20 },
                "onClick": ["goBack"]
              },
              "events": {
                "goBack": { "action": "back" }
              }
            }
            """.trimIndent()
        )
        val params = parsed.events.getValue("goBack").getJSONObject("params")
        assertEquals("back", params.getString("fun"))
    }

    @Test
    fun parsesInputWithAllFields() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "input",
                "id": "name",
                "value": "${'$'}name",
                "hint": "请输入",
                "keyboard": "email",
                "maxLength": 20,
                "layout": { "width": "fill", "height": 44 },
                "style": {
                  "color": "#1F1A17",
                  "fontSize": 16,
                  "align": "start",
                  "hintColor": "#8A8178",
                  "background": "#FFFCF8",
                  "radius": 12
                }
              }
            }
            """.trimIndent()
        )

        val input = parsed.root
        assertEquals(TemplateKey.INPUT, input.viewName)
        assertEquals("\$name", input.attrs[TemplateKey.ATTR_TEXT])
        assertEquals("请输入", input.attrs[TemplateKey.ATTR_HINT])
        assertEquals("email", input.attrs[TemplateKey.ATTR_INPUT_TYPE])
        assertEquals("20", input.attrs[TemplateKey.ATTR_MAX_LENGTH])
        assertEquals("#1F1A17", input.attrs[TemplateKey.ATTR_TEXT_COLOR])
        assertEquals("16", input.attrs[TemplateKey.ATTR_TEXT_SIZE])
        assertEquals("start", input.attrs[TemplateKey.ATTR_TEXT_ALIGN])
        assertEquals("#8A8178", input.attrs[TemplateKey.ATTR_HINT_COLOR])
        assertEquals("#FFFCF8", input.attrs[TemplateKey.ATTR_BACKGROUND])
        assertEquals("12", input.attrs[TemplateKey.ATTR_RADIUS])
        assertEquals("match_parent", input.attrs[TemplateKey.ATTR_WIDTH])
    }

    @Test
    fun inputOmitsOptionalFieldsAndDefaultsKeyboardToText() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "input",
                "layout": { "width": "fill", "height": 44 }
              }
            }
            """.trimIndent()
        )

        val input = parsed.root
        assertEquals(TemplateKey.INPUT, input.viewName)
        assertNull(input.attrs[TemplateKey.ATTR_TEXT])
        assertNull(input.attrs[TemplateKey.ATTR_HINT])
        assertNull(input.attrs[TemplateKey.ATTR_MAX_LENGTH])
        assertEquals("text", input.attrs[TemplateKey.ATTR_INPUT_TYPE])
    }

    @Test
    fun parsesCheckBoxLabelTintAndTextStyle() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "checkbox",
                "id": "agree",
                "checked": true,
                "label": "${'$'}同意",
                "layout": { "width": "fill", "height": 44 },
                "style": { "color": "#1F1A17", "fontSize": 14, "tint": "#1F6F6A" }
              }
            }
            """.trimIndent()
        )

        val box = parsed.root
        assertEquals(TemplateKey.CHECKBOX, box.viewName)
        assertEquals("true", box.attrs[TemplateKey.ATTR_CHECKED])
        assertEquals("\$同意", box.attrs[TemplateKey.ATTR_TEXT])
        assertEquals("#1F6F6A", box.attrs[TemplateKey.ATTR_TINT])
        assertEquals("#1F1A17", box.attrs[TemplateKey.ATTR_TEXT_COLOR])
        assertEquals("14", box.attrs[TemplateKey.ATTR_TEXT_SIZE])
    }

    @Test
    fun checkBoxDefaultsUncheckedAndOmitsLabel() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "checkbox",
                "layout": { "width": "fill", "height": 44 }
              }
            }
            """.trimIndent()
        )

        assertEquals(TemplateKey.CHECKBOX, parsed.root.viewName)
        assertEquals("false", parsed.root.attrs[TemplateKey.ATTR_CHECKED])
        assertNull(parsed.root.attrs[TemplateKey.ATTR_TEXT])
    }

    @Test
    fun checkBoxKeepsCheckedExpression() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "checkbox",
                "checked": "${'$'}done",
                "layout": { "width": "fill", "height": 44 }
              }
            }
            """.trimIndent()
        )

        assertEquals("\$done", parsed.root.attrs[TemplateKey.ATTR_CHECKED])
    }

    @Test
    fun rejectsInvalidInputAndCheckBoxFields() {
        assertFails("$.layout.keyboard 只能是 text、number、password、email、phone") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "input", "keyboard": "url", "layout": { "width": 1, "height": 1 } } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.maxLength 只能是非负整数") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "input", "maxLength": 1.5, "layout": { "width": 1, "height": 1 } } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.maxLength 不能是负数") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "input", "maxLength": -1, "layout": { "width": 1, "height": 1 } } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.checked 必须是布尔值或以 $ 开头") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "checkbox", "checked": "yes", "layout": { "width": 1, "height": 1 } } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.children 不是这里能写的字段") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "input", "layout": { "width": 1, "height": 1 }, "children": [] } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.style.align 不是这里能写的字段") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "checkbox", "layout": { "width": 1, "height": 1 }, "style": { "align": "start" } } }
                """.trimIndent()
            )
        }
    }

    @Test
    fun setCheckedEventChangesAttributes() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "checkbox",
                "id": "agree",
                "layout": { "width": "fill", "height": 44 }
              },
              "events": {
                "mark": { "action": "setChecked", "target": "agree", "value": false }
              }
            }
            """.trimIndent()
        )

        val event = parsed.events.getValue("mark")
        assertEquals("view", event.getString("class"))
        val params = event.getJSONObject("params")
        assertEquals("changeAttributes", params.getString("fun"))
        assertEquals("setChecked", params.getString("key"))
        assertEquals("agree", params.getString("id"))
        assertEquals("false", params.getString("value"))
    }

    @Test
    fun setCheckedEventKeepsExpressionValue() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "checkbox",
                "id": "agree",
                "layout": { "width": "fill", "height": 44 }
              },
              "events": {
                "mark": { "action": "setChecked", "target": "agree", "value": "${'$'}done" }
              }
            }
            """.trimIndent()
        )

        val params = parsed.events.getValue("mark").getJSONObject("params")
        assertEquals("\$done", params.getString("value"))
    }

    @Test
    fun appendEventCopiesItemAndTargets() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "column",
                "layout": { "width": "fill", "height": "fill" },
                "children": [
                  {
                    "type": "list",
                    "id": "chat_list",
                    "data": "${'$'}messages",
                    "layout": { "width": "fill", "height": 100 },
                    "item": {
                      "type": "text",
                      "text": "${'$'}body",
                      "layout": { "width": "fill", "height": 20 }
                    }
                  },
                  {
                    "type": "input",
                    "id": "composer",
                    "layout": { "width": "fill", "height": 44 }
                  }
                ]
              },
              "events": {
                "sendMessage": {
                  "action": "append",
                  "list": "chat_list",
                  "from": "composer",
                  "field": "body",
                  "data": "messages",
                  "empty": "先写一句",
                  "item": { "name": "我", "side": "end" }
                }
              }
            }
            """.trimIndent()
        )

        val event = parsed.events.getValue("sendMessage")
        assertEquals("list", event.getString("class"))
        val params = event.getJSONObject("params")
        assertEquals("append", params.getString("fun"))
        assertEquals("chat_list", params.getString("id"))
        assertEquals("composer", params.getString("from"))
        assertEquals("body", params.getString("field"))
        assertEquals("messages", params.getString("data"))
        assertEquals("先写一句", params.getString("empty"))
        assertEquals("我", params.getJSONObject("item").getString("name"))
        assertEquals("end", params.getJSONObject("item").getString("side"))
    }

    @Test
    fun rejectsUnrecognizedEventAction() {
        assertFails(
            "$.events.bad.action「nope」无法识别，事件 bad 只能是 toast、setText、setTextStyle、setChecked、append、open、back"
        ) {
            TemplateJsonParser.parse(
                """
                {
                  "layout": {
                    "type": "text",
                    "text": "Hi",
                    "layout": { "width": 1, "height": 1 }
                  },
                  "events": {
                    "bad": { "action": "nope" }
                  }
                }
                """.trimIndent()
            )
        }
    }

    @Test
    fun parsesRadioGroupLabelAndTint() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "radio",
                "id": "medium",
                "group": "size",
                "checked": true,
                "label": "${'$'}中杯",
                "layout": { "width": "fill", "height": 48 },
                "style": { "color": "#1F1A17", "fontSize": 15, "tint": "#1F6F6A" }
              }
            }
            """.trimIndent()
        )

        assertEquals(TemplateKey.RADIO, parsed.root.viewName)
        assertEquals("size", parsed.root.attrs[TemplateKey.ATTR_GROUP])
        assertEquals("true", parsed.root.attrs[TemplateKey.ATTR_CHECKED])
        assertEquals("\$中杯", parsed.root.attrs[TemplateKey.ATTR_TEXT])
        assertEquals("#1F6F6A", parsed.root.attrs[TemplateKey.ATTR_TINT])
        assertEquals("#1F1A17", parsed.root.attrs[TemplateKey.ATTR_TEXT_COLOR])
        assertEquals("15", parsed.root.attrs[TemplateKey.ATTR_TEXT_SIZE])
        assertEquals("match_parent", parsed.root.attrs[TemplateKey.ATTR_WIDTH])
    }

    @Test
    fun radioKeepsGroupExpressionAndDefaultsUnchecked() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "radio",
                "group": "${'$'}bundle",
                "layout": { "width": "fill", "height": 48 }
              }
            }
            """.trimIndent()
        )

        assertEquals("\$bundle", parsed.root.attrs[TemplateKey.ATTR_GROUP])
        assertEquals("false", parsed.root.attrs[TemplateKey.ATTR_CHECKED])
        assertNull(parsed.root.attrs[TemplateKey.ATTR_TEXT])
    }

    @Test
    fun rejectsInvalidRadioFields() {
        assertFails("$.layout 缺少 group") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "radio", "layout": { "width": 1, "height": 1 } } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.group「1cup」必须是字母或下划线开头的标识符，或以 $ 开头") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "radio", "group": "1cup", "layout": { "width": 1, "height": 1 } } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.checked 必须是布尔值或以 $ 开头") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "radio", "group": "size", "checked": "yes", "layout": { "width": 1, "height": 1 } } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.style.align 不是这里能写的字段") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "radio", "group": "size", "layout": { "width": 1, "height": 1 }, "style": { "align": "center" } } }
                """.trimIndent()
            )
        }
    }

    @Test
    fun parsesSwitchLabelTintAndTextStyle() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "switch",
                "id": "wifi",
                "checked": true,
                "label": "${'$'}无线",
                "layout": { "width": "fill", "height": 48 },
                "style": { "color": "#1F1A17", "fontSize": 16, "tint": "#C45C26" }
              }
            }
            """.trimIndent()
        )

        assertEquals(TemplateKey.SWITCH, parsed.root.viewName)
        assertEquals("true", parsed.root.attrs[TemplateKey.ATTR_CHECKED])
        assertEquals("\$无线", parsed.root.attrs[TemplateKey.ATTR_TEXT])
        assertEquals("#C45C26", parsed.root.attrs[TemplateKey.ATTR_TINT])
        assertEquals("#1F1A17", parsed.root.attrs[TemplateKey.ATTR_TEXT_COLOR])
        assertEquals("16", parsed.root.attrs[TemplateKey.ATTR_TEXT_SIZE])
    }

    @Test
    fun switchDefaultsOffAndOmitsLabel() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "switch",
                "checked": "${'$'}wifi",
                "layout": { "width": "fill", "height": 48 }
              }
            }
            """.trimIndent()
        )

        assertEquals("\$wifi", parsed.root.attrs[TemplateKey.ATTR_CHECKED])
        assertNull(parsed.root.attrs[TemplateKey.ATTR_TEXT])
        assertNull(parsed.root.attrs[TemplateKey.ATTR_GROUP])
    }

    @Test
    fun demoTemplatesParse() {
        val root = listOf(
            File("../Demo/src/main/assets/templates"),
            File("Demo/src/main/assets/templates")
        ).firstOrNull { it.isDirectory }
            ?: throw AssertionError("找不到 Demo 模版目录")
        listOf(
            "home-demo/home.json",
            "weather-card-demo/weather-card.json",
            "column/column.json",
            "row/row.json",
            "text/text.json",
            "image/image.json",
            "spacer/spacer.json",
            "list/list.json",
            "progress/progress.json",
            "lottie/lottie.json",
            "input/input.json",
            "checkbox/checkbox.json",
            "radio/radio.json",
            "switch/switch.json",
            "inbox/inbox.json",
            "journey/journey.json",
            "player/player.json",
            "chat/chat.json"
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
