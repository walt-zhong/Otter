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
                "lines": 3,
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
        assertEquals("3", input.attrs[TemplateKey.ATTR_LINES])
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
        assertNull(input.attrs[TemplateKey.ATTR_LINES])
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
            "$.events.bad.action「nope」无法识别，事件 bad 只能是 toast、setText、setTextStyle、setChecked、append、update、remove、open、back、replace、popTo、host"
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
    fun openWithoutParamsKeepsPageAndOmitsInnerParams() {
        val literal = TemplateJsonParser.parse(
            """
            {
              "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
              "events": { "openPage": { "action": "open", "page": "detail" } }
            }
            """.trimIndent()
        )
        val literalEvent = literal.events.getValue("openPage")
        assertEquals("nav", literalEvent.getString("class"))
        assertEquals(2, literalEvent.size)
        val literalParams = literalEvent.getJSONObject("params")
        assertEquals("open", literalParams.getString("fun"))
        assertEquals("detail", literalParams.getString("page"))
        assertEquals(2, literalParams.size)
        assertTrue(!literalParams.containsKey("params"))

        val expression = TemplateJsonParser.parse(
            """
            {
              "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
              "events": { "openPage": { "action": "open", "page": "${'$'}page" } }
            }
            """.trimIndent()
        )
        val expressionEvent = expression.events.getValue("openPage")
        assertEquals("nav", expressionEvent.getString("class"))
        val expressionParams = expressionEvent.getJSONObject("params")
        assertEquals("open", expressionParams.getString("fun"))
        assertEquals("\$page", expressionParams.getString("page"))
        assertEquals(2, expressionParams.size)
        assertTrue(!expressionParams.containsKey("params"))
    }

    @Test
    fun openParamsKeepStringNumberAndBoolean() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
              "events": {
                "openPage": {
                  "action": "open",
                  "page": "detail",
                  "params": {
                    "city": "${'$'}city",
                    "title": "北京",
                    "count": 2,
                    "ratio": 2.5,
                    "delta": -1,
                    "ok": true
                  }
                }
              }
            }
            """.trimIndent()
        )

        val event = parsed.events.getValue("openPage")
        assertEquals("nav", event.getString("class"))
        val params = event.getJSONObject("params")
        assertEquals("open", params.getString("fun"))
        assertEquals("detail", params.getString("page"))
        val inner = params.getJSONObject("params")
        assertEquals("\$city", inner.get("city"))
        assertEquals("北京", inner.get("title"))
        val count = inner.get("count")
        assertTrue(count is Number)
        assertEquals(2, (count as Number).toInt())
        val ratio = inner.get("ratio")
        assertTrue(ratio is Number)
        assertEquals(2.5, (ratio as Number).toDouble(), 0.0)
        val delta = inner.get("delta")
        assertTrue(delta is Number)
        assertEquals(-1, (delta as Number).toInt())
        assertEquals(true, inner.get("ok"))
    }

    @Test
    fun openEmptyParamsBecomesEmptyObject() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
              "events": { "openPage": { "action": "open", "page": "detail", "params": {} } }
            }
            """.trimIndent()
        )

        val params = parsed.events.getValue("openPage").getJSONObject("params")
        assertEquals("open", params.getString("fun"))
        assertEquals("detail", params.getString("page"))
        val inner = params.getJSONObject("params")
        assertEquals(0, inner.size)
    }

    @Test
    fun openParamsKeepNestedObjectAndArray() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
              "events": {
                "openPage": {
                  "action": "open",
                  "page": "detail",
                  "params": {
                    "city": { "name": "上海" },
                    "tags": ["${'$'}tag", 1]
                  }
                }
              }
            }
            """.trimIndent()
        )
        val inner = parsed.events.getValue("openPage").getJSONObject("params").getJSONObject("params")
        assertEquals("上海", inner.getJSONObject("city").getString("name"))
        assertEquals("\$tag", inner.getJSONArray("tags").getString(0))
        assertEquals(1, (inner.getJSONArray("tags").get(1) as Number).toInt())
    }

    @Test
    fun rejectsInvalidOpenParamsAndPage() {
        assertFails("$.events.openPage.params 必须是对象") {
            TemplateJsonParser.parse(
                """
                {
                  "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
                  "events": { "openPage": { "action": "open", "page": "detail", "params": [] } }
                }
                """.trimIndent()
            )
        }
        assertFails("$.events.openPage.params.city 必须是字符串、数字、布尔、对象或数组") {
            TemplateJsonParser.parse(
                """
                {
                  "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
                  "events": {
                    "openPage": { "action": "open", "page": "detail", "params": { "city": null } }
                  }
                }
                """.trimIndent()
            )
        }
        assertFails("$.events.openPage.params.1city 不是这里能写的字段") {
            TemplateJsonParser.parse(
                """
                {
                  "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
                  "events": {
                    "openPage": { "action": "open", "page": "detail", "params": { "1city": "上海" } }
                  }
                }
                """.trimIndent()
            )
        }
        assertFails("$.events.openPage.page 必须是页面名或以 $ 开头") {
            TemplateJsonParser.parse(
                """
                {
                  "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
                  "events": { "openPage": { "action": "open", "page": "1ab" } }
                }
                """.trimIndent()
            )
        }
        assertFails("$.events.openPage.target 不是这里能写的字段") {
            TemplateJsonParser.parse(
                """
                {
                  "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
                  "events": { "openPage": { "action": "open", "page": "detail", "target": "title" } }
                }
                """.trimIndent()
            )
        }
    }

    @Test
    fun backRejectsExtraFields() {
        assertFails("$.events.goBack.note 不是这里能写的字段") {
            TemplateJsonParser.parse(
                """
                {
                  "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
                  "events": { "goBack": { "action": "back", "note": "bye" } }
                }
                """.trimIndent()
            )
        }
    }

    @Test
    fun backParamsKeepTheSameValuesAsOpen() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
              "events": {
                "goBack": {
                  "action": "back",
                  "params": { "memos": "${'$'}lines", "count": 1, "ok": false }
                }
              }
            }
            """.trimIndent()
        )
        val params = parsed.events.getValue("goBack").getJSONObject("params")
        assertEquals("back", params.getString("fun"))
        val inner = params.getJSONObject("params")
        assertEquals("\$lines", inner.getString("memos"))
        assertEquals(1, (inner.get("count") as Number).toInt())
        assertEquals(false, inner.get("ok"))
    }

    @Test
    fun parsesGlassOnContainersAndFillsDefaults() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "column",
                "layout": { "width": "fill", "height": "wrap" },
                "style": { "glass": {}, "radius": 16 },
                "children": [
                  {
                    "type": "row",
                    "layout": { "width": "fill", "height": 36 },
                    "style": { "glass": { "style": "clear", "tint": "${'$'}accent", "interactive": true } }
                  },
                  {
                    "type": "spacer",
                    "layout": { "width": "fill", "height": 8 },
                    "style": {
                      "glass": { "tint": "#80FFFFFF" },
                      "border": { "color": "#66FFFFFF", "width": 0.5 }
                    }
                  },
                  {
                    "type": "list",
                    "id": "feed",
                    "data": "${'$'}items",
                    "layout": { "width": "fill", "height": 80 },
                    "item": {
                      "type": "column",
                      "layout": { "width": "fill", "height": "wrap" },
                      "style": { "glass": { "style": "clear" } }
                    }
                  }
                ]
              }
            }
            """.trimIndent()
        )

        val root = parsed.root
        assertEquals("regular", root.attrs[TemplateKey.ATTR_GLASS_STYLE])
        assertNull(root.attrs[TemplateKey.ATTR_GLASS_TINT])
        assertNull(root.attrs[TemplateKey.ATTR_GLASS_INTERACTIVE])
        assertNull(root.attrs[TemplateKey.ATTR_BACKGROUND])
        assertEquals("16", root.attrs[TemplateKey.ATTR_RADIUS])

        val row = root.children[0]
        assertEquals("clear", row.attrs[TemplateKey.ATTR_GLASS_STYLE])
        assertEquals("\$accent", row.attrs[TemplateKey.ATTR_GLASS_TINT])
        assertEquals("true", row.attrs[TemplateKey.ATTR_GLASS_INTERACTIVE])

        val spacer = root.children[1]
        assertEquals("regular", spacer.attrs[TemplateKey.ATTR_GLASS_STYLE])
        assertEquals("#80FFFFFF", spacer.attrs[TemplateKey.ATTR_GLASS_TINT])
        assertNull(spacer.attrs[TemplateKey.ATTR_GLASS_INTERACTIVE])
        assertEquals("#66FFFFFF", spacer.attrs[TemplateKey.ATTR_BORDER_COLOR])
        assertEquals("0.5", spacer.attrs[TemplateKey.ATTR_BORDER_WIDTH])

        assertNull(root.children[2].attrs[TemplateKey.ATTR_GLASS_STYLE])
        val item = root.children[2].item!!
        assertEquals("clear", item.attrs[TemplateKey.ATTR_GLASS_STYLE])
        assertNull(item.attrs[TemplateKey.ATTR_GLASS_TINT])
    }

    @Test
    fun rejectsGlassOnTheWrongNodeOrWithBackground() {
        assertFails("$.layout.style.glass 不是这里能写的字段") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 }, "style": { "glass": {} } } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.style 不能同时写 background 和 glass") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "column", "layout": { "width": 1, "height": 1 }, "style": { "background": "red", "glass": {} } } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.style.glass 必须是对象") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "column", "layout": { "width": 1, "height": 1 }, "style": { "glass": 1 } } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.style.glass.style 只能是 regular、clear") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "row", "layout": { "width": 1, "height": 1 }, "style": { "glass": { "style": "heavy" } } } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.style.glass.style 必须是字符串") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "spacer", "layout": { "width": 1, "height": 1 }, "style": { "glass": { "style": 1 } } } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.style.glass.blur 不是这里能写的字段") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "column", "layout": { "width": 1, "height": 1 }, "style": { "glass": { "blur": 12 } } } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.style.glass.tint 必须是 #RGB、#RRGGBB、#AARRGGBB、transparent，或以 \$ 开头") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "column", "layout": { "width": 1, "height": 1 }, "style": { "glass": { "tint": "white" } } } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.style.glass.tint 必须是颜色，不能是渐变") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "column", "layout": { "width": 1, "height": 1 }, "style": { "glass": { "tint": { "direction": "bottom", "colors": ["#ffffff", "#000000"] } } } } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.style.glass.interactive 必须是布尔值") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "column", "layout": { "width": 1, "height": 1 }, "style": { "glass": { "interactive": "yes" } } } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.style.glass.opacity 不是这里能写的字段") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "column", "layout": { "width": 1, "height": 1 }, "style": { "glass": { "opacity": 1 } } } }
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
            "chat/chat.json",
            "glass/glass.json",
            "stack/shelf.json",
            "stack/place.json",
            "stack/stop.json",
            "stack/memo.json",
            "market/home.json",
            "market/shop.json",
            "market/cart.json",
            "market/checkout.json",
            "market/result.json",
            "market/orders.json",
            "market/mine.json"
        ).forEach { relative ->
            val file = File(root, relative)
            assertTrue("缺少 ${file.path}", file.isFile)
            TemplateJsonParser.parse(file.readText())
        }
    }

    @Test
    fun parsesLayoutStyleAndChangeFields() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "column",
                "id": "page",
                "scroll": true,
                "visible": "${'$'}shown",
                "onChange": ["renamed"],
                "layout": {
                  "width": "fill",
                  "height": "fill",
                  "margin": { "start": 8, "end": 4, "top": 2, "bottom": 1 },
                  "wrap": true,
                  "aspectRatio": 1.5,
                  "alignSelf": "stretch",
                  "minWidth": "fill",
                  "maxHeight": "wrap"
                },
                "children": [
                  {
                    "type": "text",
                    "id": "title",
                    "text": "Hi",
                    "layout": { "width": "fill", "height": "wrap" },
                    "style": { "maxLines": 2, "ellipsis": true, "fontWeight": "medium" }
                  },
                  {
                    "type": "image",
                    "src": "res:cover",
                    "layout": { "width": 40, "height": 40 },
                    "style": { "fit": "contain", "placeholder": "#112233" }
                  },
                  {
                    "type": "input",
                    "layout": { "width": "fill", "height": 44 },
                    "style": { "lines": 3 }
                  },
                  {
                    "type": "list",
                    "id": "feed",
                    "data": "${'$'}items",
                    "layout": { "width": "fill", "height": 80 },
                    "item": {
                      "type": "text",
                      "text": "${'$'}title",
                      "layout": { "width": "fill", "height": 20 }
                    }
                  }
                ]
              },
              "events": {
                "renamed": { "action": "toast", "message": "ok" }
              }
            }
            """.trimIndent()
        )

        val page = parsed.root
        assertEquals("true", page.attrs[TemplateKey.ATTR_SCROLL])
        assertEquals("\$shown", page.attrs[TemplateKey.ATTR_VISIBLE])
        assertEquals("renamed", page.attrs[TemplateKey.ATTR_ONCHANGE])
        assertEquals("8", page.attrs[TemplateKey.ATTR_MARGIN_START])
        assertEquals("4", page.attrs[TemplateKey.ATTR_MARGIN_END])
        assertEquals("2", page.attrs[TemplateKey.ATTR_MARGIN_TOP])
        assertEquals("1", page.attrs[TemplateKey.ATTR_MARGIN_BOTTOM])
        assertNull(page.attrs[TemplateKey.ATTR_MARGIN])
        assertEquals("wrap", page.attrs[TemplateKey.ATTR_FLEX_WRAP])
        assertEquals("1.5", page.attrs[TemplateKey.ATTR_ASPECT_RATIO])
        assertEquals("stretch", page.attrs[TemplateKey.ATTR_ALIGN_SELF])
        assertEquals("match_parent", page.attrs[TemplateKey.ATTR_MIN_WIDTH])
        assertEquals("wrap_content", page.attrs[TemplateKey.ATTR_MAX_HEIGHT])

        val title = page.children[0]
        assertEquals("2", title.attrs[TemplateKey.ATTR_MAX_LINES])
        assertEquals("true", title.attrs[TemplateKey.ATTR_ELLIPSIS])
        assertEquals("medium", title.attrs[TemplateKey.ATTR_FONT_WEIGHT])

        val image = page.children[1]
        assertEquals("contain", image.attrs[TemplateKey.ATTR_IMAGE_FIT])
        assertEquals("#112233", image.attrs[TemplateKey.ATTR_PLACEHOLDER])

        assertEquals("3", page.children[2].attrs[TemplateKey.ATTR_LINES])
    }

    @Test
    fun parsesUpdateRemoveReplacePopToAndHost() {
        val parsed = TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "list",
                "id": "feed",
                "data": "${'$'}items",
                "layout": { "width": "fill", "height": 80 },
                "item": {
                  "type": "text",
                  "text": "${'$'}title",
                  "layout": { "width": "fill", "height": 20 }
                }
              },
              "events": {
                "edit": {
                  "action": "update",
                  "list": "feed",
                  "index": "${'$'}row",
                  "item": { "title": "新" }
                },
                "drop": { "action": "remove", "list": "feed", "index": 0 },
                "swap": {
                  "action": "replace",
                  "page": "detail",
                  "params": { "city": "上海" }
                },
                "backTo": { "action": "popTo", "page": "${'$'}page" },
                "share": {
                  "action": "host",
                  "name": "${'$'}sheet",
                  "params": { "ok": true }
                }
              }
            }
            """.trimIndent()
        )

        val update = parsed.events.getValue("edit")
        assertEquals("list", update.getString("class"))
        val updateParams = update.getJSONObject("params")
        assertEquals("update", updateParams.getString("fun"))
        assertEquals("feed", updateParams.getString("id"))
        assertEquals("\$row", updateParams.getString("index"))
        assertEquals("新", updateParams.getJSONObject("item").getString("title"))

        val remove = parsed.events.getValue("drop").getJSONObject("params")
        assertEquals("remove", remove.getString("fun"))
        assertEquals("feed", remove.getString("id"))
        assertEquals("0", remove.getString("index"))

        val replace = parsed.events.getValue("swap")
        assertEquals("nav", replace.getString("class"))
        val replaceParams = replace.getJSONObject("params")
        assertEquals("replace", replaceParams.getString("fun"))
        assertEquals("detail", replaceParams.getString("page"))
        assertEquals("上海", replaceParams.getJSONObject("params").getString("city"))

        val popTo = parsed.events.getValue("backTo").getJSONObject("params")
        assertEquals("popTo", popTo.getString("fun"))
        assertEquals("\$page", popTo.getString("page"))
        assertTrue(!popTo.containsKey("params"))

        val host = parsed.events.getValue("share")
        assertEquals("nav", host.getString("class"))
        val hostParams = host.getJSONObject("params")
        assertEquals("host", hostParams.getString("fun"))
        assertEquals("\$sheet", hostParams.getString("name"))
        assertEquals(true, hostParams.getJSONObject("params").get("ok"))
    }

    @Test
    fun rejectsScrollWrapStyleAndIndexMistakes() {
        assertFails("$.layout.scroll 不是这里能写的字段") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "text", "text": "Hi", "scroll": true, "layout": { "width": 1, "height": 1 } } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.layout.wrap 不是这里能写的字段") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1, "wrap": true } } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.style.fontWeight 只能是 regular、medium、bold") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 }, "style": { "fontWeight": "heavy" } } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.style.fit 只能是 cover、contain、fill") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "image", "src": "res:cover", "layout": { "width": 1, "height": 1 }, "style": { "fit": "tile" } } }
                """.trimIndent()
            )
        }
        assertFails("$.layout.onChange 不能是空数组") {
            TemplateJsonParser.parse(
                """
                { "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 }, "onChange": [] } }
                """.trimIndent()
            )
        }
        assertFails("$.events.edit.index 不能是负数") {
            TemplateJsonParser.parse(
                """
                {
                  "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
                  "events": { "edit": { "action": "update", "list": "feed", "index": -1, "item": { "title": "x" } } }
                }
                """.trimIndent()
            )
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
