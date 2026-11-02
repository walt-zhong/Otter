import XCTest
@testable import OtterCore

final class TemplateJsonParserTests: XCTestCase {
    func testParsesSizeColorGradientAndEvents() throws {
        let parsed = try TemplateJsonParser.parse(
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
                    "text": "$title",
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
            """
        )

        let root = parsed.root
        XCTAssertEqual(TemplateKey.COLUMN, root.viewName)
        expect(root.attrs[TemplateKey.ATTR_WIDTH], "match_parent")
        expect(root.attrs[TemplateKey.ATTR_HEIGHT], "wrap_content")
        expect(root.attrs[TemplateKey.ATTR_PADDING_START], "8")
        expect(root.attrs[TemplateKey.ATTR_PADDING_TOP], "4")
        expect(root.attrs[TemplateKey.ATTR_FLEX_GROW], "1")
        expect(root.attrs[TemplateKey.FLEXBOX_ATTR_JUSTIFY_CONTENT], "space-between")
        expect(root.attrs[TemplateKey.FLEXBOX_ATTR_ALIGN_ITEMS], "start")
        expect(root.attrs[TemplateKey.ATTR_BACKGROUND], "linear-gradient(to bottom, #112233, #ffffff)")
        expect(root.attrs[TemplateKey.ATTR_LEFT_TOP_RADIUS], "12")
        XCTAssertEqual(1, root.children.count)
        XCTAssertEqual(TemplateKey.TEXT, root.children[0].viewName)
        expect(root.children[0].attrs[TemplateKey.ATTR_ONCLICK], "rename")
        expect(parsed.events["rename"]?.params.id.string, "title")
    }

    func testListItemIsSeparateAndLottieGetsDefaults() throws {
        let parsed = try TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "list",
                "id": "feed",
                "data": "$items",
                "layout": { "width": "fill", "height": 120 },
                "item": {
                  "type": "lottie",
                  "src": "assets:animation/lottie-sunny",
                  "layout": { "width": 24, "height": 24 }
                }
              }
            }
            """
        )

        XCTAssertEqual(TemplateKey.OT_LIST, parsed.root.viewName)
        XCTAssertTrue(parsed.root.children.isEmpty)
        expect(parsed.root.attrs[TemplateKey.ATTR_LIST_DIRECTION], "vertical")
        let item = try XCTUnwrap(parsed.root.item)
        XCTAssertEqual(TemplateKey.ANIMATION, item.viewName)
        expect(item.attrs[TemplateKey.ATTR_ANI_REPEAT_COUNT], "infinite")
        expect(item.attrs[TemplateKey.ATTR_ANI_REPEAT_MODE], "restart")
        expect(item.attrs[TemplateKey.ATTR_ANI_AUTO_PLAY], "true")
        XCTAssertNil(parsed.root.item?.children.first)
    }

    func testProgressTrackAndBarUseEngineColorFields() throws {
        let parsed = try TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "progress",
                "layout": { "width": 80, "height": 7 },
                "from": "$start",
                "to": 0.8,
                "animate": false,
                "style": { "track": "$strokeColor", "bar": "#FFD700" }
              }
            }
            """
        )

        expect(parsed.root.attrs[TemplateKey.ATTR_STROKE_COLOR], "$strokeColor")
        expect(parsed.root.attrs[TemplateKey.ATTR_TRAIL_COLOR], "#FFD700")
        expect(parsed.root.attrs[TemplateKey.ATTR_VALUE_MIN], "$start")
        expect(parsed.root.attrs[TemplateKey.ATTR_VALUE_MAX], "0.8")
        expect(parsed.root.attrs[TemplateKey.ATTR_ANIMATE_ENABLE], "false")
    }

    func testProgressBarAcceptsGradient() throws {
        let parsed = try TemplateJsonParser.parse(
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
            """
        )

        expect(parsed.root.attrs[TemplateKey.ATTR_STROKE_COLOR], "#245566")
        expect(
            parsed.root.attrs[TemplateKey.ATTR_TRAIL_COLOR],
            "linear-gradient(to right, #7EB6C9, #F2C14E, #E07A3D)"
        )
    }

    func testRejectsUnknownFieldMissingEventAndMissingTarget() {
        assertFails("$.layout.children 不是这里能写的字段") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 }, "children": [] } }
                """
            )
        }
        assertFails("onClick 引用了不存在的事件 missing") {
            try TemplateJsonParser.parse(
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
                """
            )
        }
        assertFails("事件 rename 的 target「gone」在模版中不存在") {
            try TemplateJsonParser.parse(
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
                """
            )
        }
    }

    func testBackEventClosesThePage() throws {
        let parsed = try TemplateJsonParser.parse(
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
            """
        )
        let params = try XCTUnwrap(parsed.events["goBack"]?.getJSONObject("params"))
        expect(params.getString("fun"), "back")
    }

    func testParsesInputWithAllFields() throws {
        let parsed = try TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "input",
                "id": "name",
                "value": "$name",
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
            """
        )

        let input = parsed.root
        XCTAssertEqual(TemplateKey.INPUT, input.viewName)
        expect(input.attrs[TemplateKey.ATTR_TEXT], "$name")
        expect(input.attrs[TemplateKey.ATTR_HINT], "请输入")
        expect(input.attrs[TemplateKey.ATTR_INPUT_TYPE], "email")
        expect(input.attrs[TemplateKey.ATTR_MAX_LENGTH], "20")
        expect(input.attrs[TemplateKey.ATTR_LINES], "3")
        expect(input.attrs[TemplateKey.ATTR_TEXT_COLOR], "#1F1A17")
        expect(input.attrs[TemplateKey.ATTR_TEXT_SIZE], "16")
        expect(input.attrs[TemplateKey.ATTR_TEXT_ALIGN], "start")
        expect(input.attrs[TemplateKey.ATTR_HINT_COLOR], "#8A8178")
        expect(input.attrs[TemplateKey.ATTR_BACKGROUND], "#FFFCF8")
        expect(input.attrs[TemplateKey.ATTR_RADIUS], "12")
        expect(input.attrs[TemplateKey.ATTR_WIDTH], "match_parent")
    }

    func testInputOmitsOptionalFieldsAndDefaultsKeyboardToText() throws {
        let parsed = try TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "input",
                "layout": { "width": "fill", "height": 44 }
              }
            }
            """
        )

        let input = parsed.root
        XCTAssertEqual(TemplateKey.INPUT, input.viewName)
        XCTAssertNil(input.attrs[TemplateKey.ATTR_TEXT])
        XCTAssertNil(input.attrs[TemplateKey.ATTR_HINT])
        XCTAssertNil(input.attrs[TemplateKey.ATTR_MAX_LENGTH])
        expect(input.attrs[TemplateKey.ATTR_INPUT_TYPE], "text")
        XCTAssertNil(input.attrs[TemplateKey.ATTR_LINES])
    }

    func testParsesCheckBoxLabelTintAndTextStyle() throws {
        let parsed = try TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "checkbox",
                "id": "agree",
                "checked": true,
                "label": "$同意",
                "layout": { "width": "fill", "height": 44 },
                "style": { "color": "#1F1A17", "fontSize": 14, "tint": "#1F6F6A" }
              }
            }
            """
        )

        let box = parsed.root
        XCTAssertEqual(TemplateKey.CHECKBOX, box.viewName)
        expect(box.attrs[TemplateKey.ATTR_CHECKED], "true")
        expect(box.attrs[TemplateKey.ATTR_TEXT], "$同意")
        expect(box.attrs[TemplateKey.ATTR_TINT], "#1F6F6A")
        expect(box.attrs[TemplateKey.ATTR_TEXT_COLOR], "#1F1A17")
        expect(box.attrs[TemplateKey.ATTR_TEXT_SIZE], "14")
    }

    func testCheckBoxDefaultsUncheckedAndOmitsLabel() throws {
        let parsed = try TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "checkbox",
                "layout": { "width": "fill", "height": 44 }
              }
            }
            """
        )

        XCTAssertEqual(TemplateKey.CHECKBOX, parsed.root.viewName)
        expect(parsed.root.attrs[TemplateKey.ATTR_CHECKED], "false")
        XCTAssertNil(parsed.root.attrs[TemplateKey.ATTR_TEXT])
    }

    func testCheckBoxKeepsCheckedExpression() throws {
        let parsed = try TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "checkbox",
                "checked": "$done",
                "layout": { "width": "fill", "height": 44 }
              }
            }
            """
        )

        expect(parsed.root.attrs[TemplateKey.ATTR_CHECKED], "$done")
    }

    func testRejectsInvalidInputAndCheckBoxFields() {
        assertFails("$.layout.keyboard 只能是 text、number、password、email、phone") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "input", "keyboard": "url", "layout": { "width": 1, "height": 1 } } }
                """
            )
        }
        assertFails("$.layout.maxLength 只能是非负整数") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "input", "maxLength": 1.5, "layout": { "width": 1, "height": 1 } } }
                """
            )
        }
        assertFails("$.layout.maxLength 不能是负数") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "input", "maxLength": -1, "layout": { "width": 1, "height": 1 } } }
                """
            )
        }
        assertFails("$.layout.checked 必须是布尔值或以 $ 开头") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "checkbox", "checked": "yes", "layout": { "width": 1, "height": 1 } } }
                """
            )
        }
        assertFails("$.layout.children 不是这里能写的字段") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "input", "layout": { "width": 1, "height": 1 }, "children": [] } }
                """
            )
        }
        assertFails("$.layout.style.align 不是这里能写的字段") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "checkbox", "layout": { "width": 1, "height": 1 }, "style": { "align": "start" } } }
                """
            )
        }
    }

    func testSetCheckedEventChangesAttributes() throws {
        let parsed = try TemplateJsonParser.parse(
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
            """
        )

        let event = try XCTUnwrap(parsed.events["mark"])
        expect(event.getString("class"), "view")
        let params = try XCTUnwrap(event.getJSONObject("params"))
        expect(params.getString("fun"), "changeAttributes")
        expect(params.getString("key"), "setChecked")
        expect(params.getString("id"), "agree")
        expect(params.getString("value"), "false")
    }

    func testSetCheckedEventKeepsExpressionValue() throws {
        let parsed = try TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "checkbox",
                "id": "agree",
                "layout": { "width": "fill", "height": 44 }
              },
              "events": {
                "mark": { "action": "setChecked", "target": "agree", "value": "$done" }
              }
            }
            """
        )

        let params = try XCTUnwrap(parsed.events["mark"]?.getJSONObject("params"))
        expect(params.getString("value"), "$done")
    }

    func testAppendEventCopiesItemAndTargets() throws {
        let parsed = try TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "column",
                "layout": { "width": "fill", "height": "fill" },
                "children": [
                  {
                    "type": "list",
                    "id": "chat_list",
                    "data": "$messages",
                    "layout": { "width": "fill", "height": 100 },
                    "item": {
                      "type": "text",
                      "text": "$body",
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
            """
        )

        let event = try XCTUnwrap(parsed.events["sendMessage"])
        expect(event.getString("class"), "list")
        let params = try XCTUnwrap(event.getJSONObject("params"))
        expect(params.getString("fun"), "append")
        expect(params.getString("id"), "chat_list")
        expect(params.getString("from"), "composer")
        expect(params.getString("field"), "body")
        expect(params.getString("data"), "messages")
        expect(params.getString("empty"), "先写一句")
        let item = try XCTUnwrap(params.getJSONObject("item"))
        expect(item.getString("name"), "我")
        expect(item.getString("side"), "end")
    }

    func testRejectsUnrecognizedEventAction() {
        assertFails(
            "$.events.bad.action「nope」无法识别，事件 bad 只能是 toast、setText、setTextStyle、setChecked、append、update、remove、open、back、replace、popTo、host"
        ) {
            try TemplateJsonParser.parse(
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
                """
            )
        }
    }

    func testParsesRadioGroupLabelAndTint() throws {
        let parsed = try TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "radio",
                "id": "medium",
                "group": "size",
                "checked": true,
                "label": "$中杯",
                "layout": { "width": "fill", "height": 48 },
                "style": { "color": "#1F1A17", "fontSize": 15, "tint": "#1F6F6A" }
              }
            }
            """
        )

        XCTAssertEqual(TemplateKey.RADIO, parsed.root.viewName)
        expect(parsed.root.attrs[TemplateKey.ATTR_GROUP], "size")
        expect(parsed.root.attrs[TemplateKey.ATTR_CHECKED], "true")
        expect(parsed.root.attrs[TemplateKey.ATTR_TEXT], "$中杯")
        expect(parsed.root.attrs[TemplateKey.ATTR_TINT], "#1F6F6A")
        expect(parsed.root.attrs[TemplateKey.ATTR_TEXT_COLOR], "#1F1A17")
        expect(parsed.root.attrs[TemplateKey.ATTR_TEXT_SIZE], "15")
        expect(parsed.root.attrs[TemplateKey.ATTR_WIDTH], "match_parent")
    }

    func testRadioKeepsGroupExpressionAndDefaultsUnchecked() throws {
        let parsed = try TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "radio",
                "group": "$bundle",
                "layout": { "width": "fill", "height": 48 }
              }
            }
            """
        )

        expect(parsed.root.attrs[TemplateKey.ATTR_GROUP], "$bundle")
        expect(parsed.root.attrs[TemplateKey.ATTR_CHECKED], "false")
        XCTAssertNil(parsed.root.attrs[TemplateKey.ATTR_TEXT])
    }

    func testRejectsInvalidRadioFields() {
        assertFails("$.layout 缺少 group") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "radio", "layout": { "width": 1, "height": 1 } } }
                """
            )
        }
        assertFails("$.layout.group「1cup」必须是字母或下划线开头的标识符，或以 $ 开头") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "radio", "group": "1cup", "layout": { "width": 1, "height": 1 } } }
                """
            )
        }
        assertFails("$.layout.checked 必须是布尔值或以 $ 开头") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "radio", "group": "size", "checked": "yes", "layout": { "width": 1, "height": 1 } } }
                """
            )
        }
        assertFails("$.layout.style.align 不是这里能写的字段") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "radio", "group": "size", "layout": { "width": 1, "height": 1 }, "style": { "align": "center" } } }
                """
            )
        }
    }

    func testParsesSwitchLabelTintAndTextStyle() throws {
        let parsed = try TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "switch",
                "id": "wifi",
                "checked": true,
                "label": "$无线",
                "layout": { "width": "fill", "height": 48 },
                "style": { "color": "#1F1A17", "fontSize": 16, "tint": "#C45C26" }
              }
            }
            """
        )

        XCTAssertEqual(TemplateKey.SWITCH, parsed.root.viewName)
        expect(parsed.root.attrs[TemplateKey.ATTR_CHECKED], "true")
        expect(parsed.root.attrs[TemplateKey.ATTR_TEXT], "$无线")
        expect(parsed.root.attrs[TemplateKey.ATTR_TINT], "#C45C26")
        expect(parsed.root.attrs[TemplateKey.ATTR_TEXT_COLOR], "#1F1A17")
        expect(parsed.root.attrs[TemplateKey.ATTR_TEXT_SIZE], "16")
    }

    func testSwitchDefaultsOffAndOmitsLabel() throws {
        let parsed = try TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "switch",
                "checked": "$wifi",
                "layout": { "width": "fill", "height": 48 }
              }
            }
            """
        )

        expect(parsed.root.attrs[TemplateKey.ATTR_CHECKED], "$wifi")
        XCTAssertNil(parsed.root.attrs[TemplateKey.ATTR_TEXT])
        XCTAssertNil(parsed.root.attrs[TemplateKey.ATTR_GROUP])
    }

    func testOpenWithoutParamsKeepsPageAndOmitsInnerParams() throws {
        let literal = try TemplateJsonParser.parse(
            """
            {
              "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
              "events": { "openPage": { "action": "open", "page": "detail" } }
            }
            """
        )
        let literalEvent = try XCTUnwrap(literal.events["openPage"])
        expect(literalEvent.getString("class"), "nav")
        XCTAssertEqual(2, literalEvent.size)
        let literalParams = try XCTUnwrap(literalEvent.getJSONObject("params"))
        expect(literalParams.getString("fun"), "open")
        expect(literalParams.getString("page"), "detail")
        XCTAssertEqual(2, literalParams.size)
        XCTAssertTrue(!literalParams.containsKey("params"))

        let expression = try TemplateJsonParser.parse(
            """
            {
              "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
              "events": { "openPage": { "action": "open", "page": "$page" } }
            }
            """
        )
        let expressionEvent = try XCTUnwrap(expression.events["openPage"])
        expect(expressionEvent.getString("class"), "nav")
        let expressionParams = try XCTUnwrap(expressionEvent.getJSONObject("params"))
        expect(expressionParams.getString("fun"), "open")
        expect(expressionParams.getString("page"), "$page")
        XCTAssertEqual(2, expressionParams.size)
        XCTAssertTrue(!expressionParams.containsKey("params"))
    }

    func testOpenParamsKeepStringNumberAndBoolean() throws {
        let parsed = try TemplateJsonParser.parse(
            """
            {
              "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
              "events": {
                "openPage": {
                  "action": "open",
                  "page": "detail",
                  "params": {
                    "city": "$city",
                    "title": "北京",
                    "count": 2,
                    "ratio": 2.5,
                    "delta": -1,
                    "ok": true
                  }
                }
              }
            }
            """
        )

        let event = try XCTUnwrap(parsed.events["openPage"])
        expect(event.getString("class"), "nav")
        let params = try XCTUnwrap(event.getJSONObject("params"))
        expect(params.getString("fun"), "open")
        expect(params.getString("page"), "detail")
        let inner = try XCTUnwrap(params.getJSONObject("params"))
        expectValue(inner.get("city"), .string("$city"))
        expectValue(inner.get("title"), .string("北京"))
        assertNumber(inner.get("count"), int: 2)
        assertNumber(inner.get("ratio"), double: 2.5)
        assertNumber(inner.get("delta"), int: -1)
        expectValue(inner.get("ok"), .bool(true))
    }

    func testOpenEmptyParamsBecomesEmptyObject() throws {
        let parsed = try TemplateJsonParser.parse(
            """
            {
              "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
              "events": { "openPage": { "action": "open", "page": "detail", "params": {} } }
            }
            """
        )

        let params = try XCTUnwrap(parsed.events["openPage"]?.getJSONObject("params"))
        expect(params.getString("fun"), "open")
        expect(params.getString("page"), "detail")
        let inner = try XCTUnwrap(params.getJSONObject("params"))
        XCTAssertEqual(0, inner.size)
    }

    func testOpenParamsKeepNestedObjectAndArray() throws {
        let parsed = try TemplateJsonParser.parse(
            """
            {
              "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
              "events": {
                "openPage": {
                  "action": "open",
                  "page": "detail",
                  "params": {
                    "city": { "name": "上海" },
                    "tags": ["$tag", 1]
                  }
                }
              }
            }
            """
        )
        let inner = try XCTUnwrap(
            parsed.events["openPage"]?.getJSONObject("params")?.getJSONObject("params")
        )
        expect(inner.getJSONObject("city")?.getString("name"), "上海")
        let tags = try XCTUnwrap(inner.getJSONArray("tags"))
        expect(tags.getString(0), "$tag")
        assertNumber(tags.get(1), int: 1)
    }

    func testRejectsInvalidOpenParamsAndPage() {
        assertFails("$.events.openPage.params 必须是对象") {
            try TemplateJsonParser.parse(
                """
                {
                  "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
                  "events": { "openPage": { "action": "open", "page": "detail", "params": [] } }
                }
                """
            )
        }
        assertFails("$.events.openPage.params.city 必须是字符串、数字、布尔、对象或数组") {
            try TemplateJsonParser.parse(
                """
                {
                  "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
                  "events": {
                    "openPage": { "action": "open", "page": "detail", "params": { "city": null } }
                  }
                }
                """
            )
        }
        assertFails("$.events.openPage.params.1city 不是这里能写的字段") {
            try TemplateJsonParser.parse(
                """
                {
                  "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
                  "events": {
                    "openPage": { "action": "open", "page": "detail", "params": { "1city": "上海" } }
                  }
                }
                """
            )
        }
        assertFails("$.events.openPage.page 必须是页面名或以 $ 开头") {
            try TemplateJsonParser.parse(
                """
                {
                  "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
                  "events": { "openPage": { "action": "open", "page": "1ab" } }
                }
                """
            )
        }
        assertFails("$.events.openPage.target 不是这里能写的字段") {
            try TemplateJsonParser.parse(
                """
                {
                  "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
                  "events": { "openPage": { "action": "open", "page": "detail", "target": "title" } }
                }
                """
            )
        }
    }

    func testBackRejectsExtraFields() {
        assertFails("$.events.goBack.note 不是这里能写的字段") {
            try TemplateJsonParser.parse(
                """
                {
                  "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
                  "events": { "goBack": { "action": "back", "note": "bye" } }
                }
                """
            )
        }
    }

    func testBackParamsKeepTheSameValuesAsOpen() throws {
        let parsed = try TemplateJsonParser.parse(
            """
            {
              "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
              "events": {
                "goBack": {
                  "action": "back",
                  "params": { "memos": "$lines", "count": 1, "ok": false }
                }
              }
            }
            """
        )
        let params = try XCTUnwrap(parsed.events["goBack"]?.getJSONObject("params"))
        expect(params.getString("fun"), "back")
        let inner = try XCTUnwrap(params.getJSONObject("params"))
        expect(inner.getString("memos"), "$lines")
        assertNumber(inner.get("count"), int: 1)
        expectValue(inner.get("ok"), .bool(false))
    }

    func testParsesGlassOnContainersAndFillsDefaults() throws {
        let parsed = try TemplateJsonParser.parse(
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
                    "style": { "glass": { "style": "clear", "tint": "$accent", "interactive": true } }
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
                    "data": "$items",
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
            """
        )

        let root = parsed.root
        expect(root.attrs[TemplateKey.ATTR_GLASS_STYLE], "regular")
        XCTAssertNil(root.attrs[TemplateKey.ATTR_GLASS_TINT])
        XCTAssertNil(root.attrs[TemplateKey.ATTR_GLASS_INTERACTIVE])
        XCTAssertNil(root.attrs[TemplateKey.ATTR_BACKGROUND])
        expect(root.attrs[TemplateKey.ATTR_RADIUS], "16")

        let row = root.children[0]
        expect(row.attrs[TemplateKey.ATTR_GLASS_STYLE], "clear")
        expect(row.attrs[TemplateKey.ATTR_GLASS_TINT], "$accent")
        expect(row.attrs[TemplateKey.ATTR_GLASS_INTERACTIVE], "true")

        let spacer = root.children[1]
        expect(spacer.attrs[TemplateKey.ATTR_GLASS_STYLE], "regular")
        expect(spacer.attrs[TemplateKey.ATTR_GLASS_TINT], "#80FFFFFF")
        XCTAssertNil(spacer.attrs[TemplateKey.ATTR_GLASS_INTERACTIVE])
        expect(spacer.attrs[TemplateKey.ATTR_BORDER_COLOR], "#66FFFFFF")
        expect(spacer.attrs[TemplateKey.ATTR_BORDER_WIDTH], "0.5")

        XCTAssertNil(root.children[2].attrs[TemplateKey.ATTR_GLASS_STYLE])
        let item = try XCTUnwrap(root.children[2].item)
        expect(item.attrs[TemplateKey.ATTR_GLASS_STYLE], "clear")
        XCTAssertNil(item.attrs[TemplateKey.ATTR_GLASS_TINT])
    }

    func testRejectsGlassOnTheWrongNodeOrWithBackground() {
        assertFails("$.layout.style.glass 不是这里能写的字段") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 }, "style": { "glass": {} } } }
                """
            )
        }
        assertFails("$.layout.style 不能同时写 background 和 glass") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "column", "layout": { "width": 1, "height": 1 }, "style": { "background": "red", "glass": {} } } }
                """
            )
        }
        assertFails("$.layout.style.glass 必须是对象") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "column", "layout": { "width": 1, "height": 1 }, "style": { "glass": 1 } } }
                """
            )
        }
        assertFails("$.layout.style.glass.style 只能是 regular、clear") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "row", "layout": { "width": 1, "height": 1 }, "style": { "glass": { "style": "heavy" } } } }
                """
            )
        }
        assertFails("$.layout.style.glass.style 必须是字符串") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "spacer", "layout": { "width": 1, "height": 1 }, "style": { "glass": { "style": 1 } } } }
                """
            )
        }
        assertFails("$.layout.style.glass.blur 不是这里能写的字段") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "column", "layout": { "width": 1, "height": 1 }, "style": { "glass": { "blur": 12 } } } }
                """
            )
        }
        assertFails("$.layout.style.glass.tint 必须是 #RGB、#RRGGBB、#AARRGGBB、transparent，或以 $ 开头") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "column", "layout": { "width": 1, "height": 1 }, "style": { "glass": { "tint": "white" } } } }
                """
            )
        }
        assertFails("$.layout.style.glass.tint 必须是颜色，不能是渐变") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "column", "layout": { "width": 1, "height": 1 }, "style": { "glass": { "tint": { "direction": "bottom", "colors": ["#ffffff", "#000000"] } } } } }
                """
            )
        }
        assertFails("$.layout.style.glass.interactive 必须是布尔值") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "column", "layout": { "width": 1, "height": 1 }, "style": { "glass": { "interactive": "yes" } } } }
                """
            )
        }
        assertFails("$.layout.style.glass.opacity 不是这里能写的字段") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "column", "layout": { "width": 1, "height": 1 }, "style": { "glass": { "opacity": 1 } } } }
                """
            )
        }
    }

    func testDemoTemplatesParse() throws {
        let root = firstExistingDirectory([
            "../Demo/src/main/assets/templates",
            "Demo/src/main/assets/templates"
        ])
        XCTAssertNotNil(root, "找不到 Demo 模版目录")
        guard let root else { return }
        let relatives = [
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
        ]
        for relative in relatives {
            let file = root.appendingPathComponent(relative)
            XCTAssertTrue(isFile(file.path), "缺少 \(file.path)")
            let text = try String(contentsOf: file, encoding: .utf8)
            _ = try TemplateJsonParser.parse(text)
        }
    }

    func testParsesLayoutStyleAndChangeFields() throws {
        let parsed = try TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "column",
                "id": "page",
                "scroll": true,
                "visible": "$shown",
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
                    "data": "$items",
                    "layout": { "width": "fill", "height": 80 },
                    "item": {
                      "type": "text",
                      "text": "$title",
                      "layout": { "width": "fill", "height": 20 }
                    }
                  }
                ]
              },
              "events": {
                "renamed": { "action": "toast", "message": "ok" }
              }
            }
            """
        )

        let page = parsed.root
        expect(page.attrs[TemplateKey.ATTR_SCROLL], "true")
        expect(page.attrs[TemplateKey.ATTR_VISIBLE], "$shown")
        expect(page.attrs[TemplateKey.ATTR_ONCHANGE], "renamed")
        expect(page.attrs[TemplateKey.ATTR_MARGIN_START], "8")
        expect(page.attrs[TemplateKey.ATTR_MARGIN_END], "4")
        expect(page.attrs[TemplateKey.ATTR_MARGIN_TOP], "2")
        expect(page.attrs[TemplateKey.ATTR_MARGIN_BOTTOM], "1")
        XCTAssertNil(page.attrs[TemplateKey.ATTR_MARGIN])
        expect(page.attrs[TemplateKey.ATTR_FLEX_WRAP], "wrap")
        expect(page.attrs[TemplateKey.ATTR_ASPECT_RATIO], "1.5")
        expect(page.attrs[TemplateKey.ATTR_ALIGN_SELF], "stretch")
        expect(page.attrs[TemplateKey.ATTR_MIN_WIDTH], "match_parent")
        expect(page.attrs[TemplateKey.ATTR_MAX_HEIGHT], "wrap_content")

        let title = page.children[0]
        expect(title.attrs[TemplateKey.ATTR_MAX_LINES], "2")
        expect(title.attrs[TemplateKey.ATTR_ELLIPSIS], "true")
        expect(title.attrs[TemplateKey.ATTR_FONT_WEIGHT], "medium")

        let image = page.children[1]
        expect(image.attrs[TemplateKey.ATTR_IMAGE_FIT], "contain")
        expect(image.attrs[TemplateKey.ATTR_PLACEHOLDER], "#112233")

        expect(page.children[2].attrs[TemplateKey.ATTR_LINES], "3")
    }

    func testParsesUpdateRemoveReplacePopToAndHost() throws {
        let parsed = try TemplateJsonParser.parse(
            """
            {
              "layout": {
                "type": "list",
                "id": "feed",
                "data": "$items",
                "layout": { "width": "fill", "height": 80 },
                "item": {
                  "type": "text",
                  "text": "$title",
                  "layout": { "width": "fill", "height": 20 }
                }
              },
              "events": {
                "edit": {
                  "action": "update",
                  "list": "feed",
                  "index": "$row",
                  "item": { "title": "新" }
                },
                "drop": { "action": "remove", "list": "feed", "index": 0 },
                "swap": {
                  "action": "replace",
                  "page": "detail",
                  "params": { "city": "上海" }
                },
                "backTo": { "action": "popTo", "page": "$page" },
                "share": {
                  "action": "host",
                  "name": "$sheet",
                  "params": { "ok": true }
                }
              }
            }
            """
        )

        let update = try XCTUnwrap(parsed.events["edit"])
        expect(update.getString("class"), "list")
        let updateParams = try XCTUnwrap(update.getJSONObject("params"))
        expect(updateParams.getString("fun"), "update")
        expect(updateParams.getString("id"), "feed")
        expect(updateParams.getString("index"), "$row")
        expect(updateParams.getJSONObject("item")?.getString("title"), "新")

        let remove = try XCTUnwrap(parsed.events["drop"]?.getJSONObject("params"))
        expect(remove.getString("fun"), "remove")
        expect(remove.getString("id"), "feed")
        expect(remove.getString("index"), "0")

        let replace = try XCTUnwrap(parsed.events["swap"])
        expect(replace.getString("class"), "nav")
        let replaceParams = try XCTUnwrap(replace.getJSONObject("params"))
        expect(replaceParams.getString("fun"), "replace")
        expect(replaceParams.getString("page"), "detail")
        expect(replaceParams.getJSONObject("params")?.getString("city"), "上海")

        let popTo = try XCTUnwrap(parsed.events["backTo"]?.getJSONObject("params"))
        expect(popTo.getString("fun"), "popTo")
        expect(popTo.getString("page"), "$page")
        XCTAssertTrue(!popTo.containsKey("params"))

        let host = try XCTUnwrap(parsed.events["share"])
        expect(host.getString("class"), "nav")
        let hostParams = try XCTUnwrap(host.getJSONObject("params"))
        expect(hostParams.getString("fun"), "host")
        expect(hostParams.getString("name"), "$sheet")
        expectValue(hostParams.getJSONObject("params")?.get("ok"), .bool(true))
    }

    func testRejectsScrollWrapStyleAndIndexMistakes() {
        assertFails("$.layout.scroll 不是这里能写的字段") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "text", "text": "Hi", "scroll": true, "layout": { "width": 1, "height": 1 } } }
                """
            )
        }
        assertFails("$.layout.layout.wrap 不是这里能写的字段") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1, "wrap": true } } }
                """
            )
        }
        assertFails("$.layout.style.fontWeight 只能是 regular、medium、bold") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 }, "style": { "fontWeight": "heavy" } } }
                """
            )
        }
        assertFails("$.layout.style.fit 只能是 cover、contain、fill") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "image", "src": "res:cover", "layout": { "width": 1, "height": 1 }, "style": { "fit": "tile" } } }
                """
            )
        }
        assertFails("$.layout.onChange 不能是空数组") {
            try TemplateJsonParser.parse(
                """
                { "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 }, "onChange": [] } }
                """
            )
        }
        assertFails("$.events.edit.index 不能是负数") {
            try TemplateJsonParser.parse(
                """
                {
                  "layout": { "type": "text", "text": "Hi", "layout": { "width": 1, "height": 1 } },
                  "events": { "edit": { "action": "update", "list": "feed", "index": -1, "item": { "title": "x" } } }
                }
                """
            )
        }
    }
}
