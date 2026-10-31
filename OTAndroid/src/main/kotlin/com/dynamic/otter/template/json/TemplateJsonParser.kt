package com.dynamic.otter.template.json

import com.alibaba.fastjson.JSON
import com.alibaba.fastjson.JSONArray
import com.alibaba.fastjson.JSONException
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.data.TemplateKey
import java.math.BigDecimal

class TemplateParseException(message: String) : IllegalArgumentException(message)

data class ParsedNode(
    val viewName: String,
    val id: String,
    val attrs: Map<String, String>,
    val children: List<ParsedNode> = emptyList(),
    val item: ParsedNode? = null
)

data class ParsedTemplate(
    val root: ParsedNode,
    val events: Map<String, JSONObject>
)

object TemplateJsonParser {
    private val namePattern = Regex("[A-Za-z_][A-Za-z0-9_]*")
    private val colorPattern = Regex("#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})")

    private val justifyValues = mapOf(
        "start" to "start",
        "center" to "center",
        "end" to "end",
        "spaceBetween" to "space-between",
        "spaceAround" to "space-around",
        "spaceEvenly" to "space-evenly"
    )
    private val alignValues = mapOf(
        "start" to "start",
        "center" to "center",
        "end" to "end",
        "baseline" to "baseline",
        "stretch" to "stretch"
    )
    private val textAlignValues = setOf("start", "center", "end")
    private val keyboardValues = setOf("text", "number", "password", "email", "phone")
    private val gradientDirections = mapOf(
        "bottom" to "to bottom",
        "top" to "to top",
        "left" to "to left",
        "right" to "to right",
        "topLeft" to "to top left",
        "topRight" to "to top right",
        "bottomLeft" to "to bottom left",
        "bottomRight" to "to bottom right"
    )
    private val viewNames = mapOf(
        "column" to TemplateKey.COLUMN,
        "row" to TemplateKey.ROW,
        "text" to TemplateKey.TEXT,
        "image" to TemplateKey.IMAGE,
        "spacer" to TemplateKey.SPACER,
        "list" to TemplateKey.OT_LIST,
        "progress" to TemplateKey.PROGRESS,
        "lottie" to TemplateKey.ANIMATION,
        "input" to TemplateKey.INPUT,
        "checkbox" to TemplateKey.CHECKBOX,
        "radio" to TemplateKey.RADIO,
        "switch" to TemplateKey.SWITCH
    )

    fun parse(json: String): ParsedTemplate {
        val root = try {
            JSON.parseObject(json)
        } catch (error: JSONException) {
            throw TemplateParseException("模版不是合法 JSON：${error.message}")
        } ?: throw TemplateParseException("模版必须是 JSON 对象")

        requireKeys(root, "$", allowed = setOf("layout", "events"), required = setOf("layout"))
        val events = parseEvents(root.get("events"), "$.events")
        val ids = linkedSetOf<String>()
        val clicks = mutableListOf<String>()
        val layout = parseNode(
            requireObject(root.get("layout"), "$.layout"),
            "$.layout",
            ids,
            clicks
        )
        clicks.forEach { name ->
            if (!events.containsKey(name)) {
                throw TemplateParseException("onClick 引用了不存在的事件 $name")
            }
        }
        events.forEach { (name, event) ->
            val params = event.getJSONObject("params") ?: return@forEach
            val targets = mutableListOf<String>()
            params.getString("id")?.split(",")?.let { targets.addAll(it) }
            params.getString("from")?.let { targets.add(it) }
            targets.forEach { id ->
                if (id.isNotEmpty() && id !in ids) {
                    throw TemplateParseException("事件 $name 的 target「$id」在模版中不存在")
                }
            }
        }
        return ParsedTemplate(layout, events)
    }

    private fun parseEvents(value: Any?, path: String): Map<String, JSONObject> {
        if (value == null) {
            return emptyMap()
        }
        val events = requireObject(value, path)
        val result = linkedMapOf<String, JSONObject>()
        events.forEach { entry ->
            val name = entry.key
            if (!namePattern.matches(name)) {
                throw TemplateParseException("$path 的事件名「$name」必须是字母或下划线开头的标识符")
            }
            result[name] = parseEvent(name, requireObject(entry.value, "$path.$name"), "$path.$name")
        }
        return result
    }

    private fun parseEvent(name: String, event: JSONObject, path: String): JSONObject {
        val action = event.get("action") as? String
            ?: throw TemplateParseException("$path 缺少 action")
        return when (action) {
            "toast" -> {
                requireKeys(event, path, allowed = setOf("action", "message"), required = setOf("action", "message"))
                val message = requireString(event.get("message"), "$path.message")
                jsonObject(
                    "class" to "util",
                    "params" to jsonObject("fun" to "showToast", "info" to message)
                )
            }

            "setText" -> {
                requireKeys(
                    event,
                    path,
                    allowed = setOf("action", "target", "value"),
                    required = setOf("action", "target", "value")
                )
                viewEvent(
                    key = "setText",
                    target = requireName(event.get("target"), "$path.target"),
                    value = requireString(event.get("value"), "$path.value")
                )
            }

            "setTextStyle" -> {
                requireKeys(
                    event,
                    path,
                    allowed = setOf("action", "target", "fontSize", "color", "text"),
                    required = setOf("action", "target")
                )
                val style = JSONObject()
                if (event.containsKey("fontSize")) {
                    style[TemplateKey.ATTR_TEXT_SIZE] = plainNumber(event.get("fontSize"), "$path.fontSize")
                }
                if (event.containsKey("color")) {
                    style[TemplateKey.ATTR_TEXT_COLOR] = colorValue(event.get("color"), "$path.color")
                }
                if (event.containsKey("text")) {
                    style[TemplateKey.ATTR_TEXT] = requireString(event.get("text"), "$path.text")
                }
                if (style.isEmpty()) {
                    throw TemplateParseException("$path 至少要写 fontSize、color、text 中的一个")
                }
                val attributes = JSONArray()
                attributes.add(style)
                viewEvent(
                    key = "setTextStyle",
                    target = requireName(event.get("target"), "$path.target"),
                    value = jsonObject("attributes" to attributes)
                )
            }

            "setChecked" -> {
                requireKeys(
                    event,
                    path,
                    allowed = setOf("action", "target", "value"),
                    required = setOf("action", "target", "value")
                )
                val targets = targetList(event.get("target"), "$path.target")
                viewEvent(
                    key = "setChecked",
                    target = targets.joinToString(","),
                    value = checkedValue(event.get("value"), "$path.value")
                )
            }

            "append" -> parseAppendEvent(event, path)

            "open" -> {
                requireKeys(event, path, allowed = setOf("action", "page"), required = setOf("action", "page"))
                val page = requireString(event.get("page"), "$path.page")
                if (!page.startsWith("$") && !namePattern.matches(page)) {
                    throw TemplateParseException("$path.page 必须是页面名或以 \$ 开头")
                }
                jsonObject(
                    "class" to "nav",
                    "params" to jsonObject("fun" to "open", "page" to page)
                )
            }

            "back" -> {
                requireKeys(event, path, allowed = setOf("action"), required = setOf("action"))
                jsonObject(
                    "class" to "nav",
                    "params" to jsonObject("fun" to "back")
                )
            }

            else -> throw TemplateParseException("$path.action「$action」无法识别，事件 $name 只能是 toast、setText、setTextStyle、setChecked、append、open、back")
        }
    }

    private fun parseAppendEvent(event: JSONObject, path: String): JSONObject {
        requireKeys(
            event,
            path,
            allowed = setOf("action", "list", "from", "field", "data", "item", "empty"),
            required = setOf("action", "list", "from", "field", "data", "item")
        )
        val item = requireObject(event.get("item"), "$path.item")
        val fields = JSONObject()
        item.keys.forEach { key ->
            if (!namePattern.matches(key)) {
                throw TemplateParseException("$path.item.$key 不是这里能写的字段")
            }
            fields[key] = requireString(item.get(key), "$path.item.$key")
        }
        val params = jsonObject(
            "fun" to "append",
            "id" to requireName(event.get("list"), "$path.list"),
            "from" to requireName(event.get("from"), "$path.from"),
            "field" to requireName(event.get("field"), "$path.field"),
            "data" to requireName(event.get("data"), "$path.data"),
            "item" to fields
        )
        if (event.containsKey("empty")) {
            params["empty"] = requireString(event.get("empty"), "$path.empty")
        }
        return jsonObject("class" to "list", "params" to params)
    }

    private fun viewEvent(key: String, target: String, value: Any): JSONObject {
        return jsonObject(
            "class" to "view",
            "params" to jsonObject(
                "fun" to "changeAttributes",
                "key" to key,
                "id" to target,
                "value" to value
            )
        )
    }

    private fun parseNode(
        node: JSONObject,
        path: String,
        ids: MutableSet<String>,
        clicks: MutableList<String>
    ): ParsedNode {
        val type = node.get("type") as? String
            ?: throw TemplateParseException("$path 缺少 type")
        val viewName = viewNames[type]
            ?: throw TemplateParseException("$path.type「$type」无法识别")
        val isContainer = type == "column" || type == "row"
        val allowed = linkedSetOf("type", "id", "layout", "style", "onClick")
        val required = linkedSetOf("type", "layout")
        when (type) {
            "column", "row" -> allowed.add("children")
            "text" -> {
                allowed.add("text")
                required.add("text")
            }
            "image" -> {
                allowed.add("src")
                required.add("src")
            }
            "list" -> {
                allowed.addAll(listOf("data", "direction", "gap", "item"))
                required.addAll(listOf("id", "data", "item"))
            }
            "progress" -> allowed.addAll(listOf("from", "to", "animate"))
            "lottie" -> {
                allowed.addAll(listOf("src", "repeat", "mode", "autoPlay"))
                required.add("src")
            }
            "input" -> allowed.addAll(listOf("value", "hint", "keyboard", "maxLength"))
            "checkbox", "switch" -> allowed.addAll(listOf("checked", "label"))
            "radio" -> {
                allowed.addAll(listOf("checked", "label", "group"))
                required.add("group")
            }
        }
        requireKeys(node, path, allowed, required)

        val id = if (node.containsKey("id")) {
            requireName(node.get("id"), "$path.id")
        } else {
            "0"
        }
        if (id != "0") {
            ids.add(id)
        }

        val attrs = linkedMapOf<String, String>()
        if (id != "0") {
            attrs[TemplateKey.ATTR_ID] = id
        }
        parseLayout(requireObject(node.get("layout"), "$path.layout"), "$path.layout", isContainer, attrs)
        if (node.containsKey("style")) {
            parseStyle(requireObject(node.get("style"), "$path.style"), "$path.style", type, attrs)
        }
        if (node.containsKey("onClick")) {
            val names = parseNames(node.get("onClick"), "$path.onClick")
            if (names.isEmpty()) {
                throw TemplateParseException("$path.onClick 不能是空数组")
            }
            clicks.addAll(names)
            attrs[TemplateKey.ATTR_ONCLICK] = names.joinToString(",")
        }

        when (type) {
            "text" -> attrs[TemplateKey.ATTR_TEXT] = requireString(node.get("text"), "$path.text")
            "image" -> attrs[TemplateKey.ATTR_SRC] = requireString(node.get("src"), "$path.src")
            "list" -> parseListFields(node, path, attrs)
            "progress" -> parseProgressFields(node, path, attrs)
            "lottie" -> parseLottieFields(node, path, attrs)
            "input" -> parseInputFields(node, path, attrs)
            "checkbox", "switch" -> parseCheckBoxFields(node, path, attrs)
            "radio" -> parseRadioFields(node, path, attrs)
        }

        val children = if (isContainer && node.containsKey("children")) {
            val array = requireArray(node.get("children"), "$path.children")
            array.mapIndexed { index, child ->
                parseNode(requireObject(child, "$path.children[$index]"), "$path.children[$index]", ids, clicks)
            }
        } else {
            emptyList()
        }
        val item = if (type == "list") {
            parseNode(requireObject(node.get("item"), "$path.item"), "$path.item", ids, clicks)
        } else {
            null
        }
        return ParsedNode(viewName, id, attrs, children, item)
    }

    private fun parseLayout(
        layout: JSONObject,
        path: String,
        isContainer: Boolean,
        attrs: MutableMap<String, String>
    ) {
        val allowed = linkedSetOf("width", "height", "padding", "grow")
        if (isContainer) {
            allowed.add("justify")
            allowed.add("align")
        }
        requireKeys(layout, path, allowed, required = setOf("width", "height"))
        attrs[TemplateKey.ATTR_WIDTH] = sizeValue(layout.get("width"), "$path.width")
        attrs[TemplateKey.ATTR_HEIGHT] = sizeValue(layout.get("height"), "$path.height")
        if (layout.containsKey("padding")) {
            parsePadding(layout.get("padding"), "$path.padding", attrs)
        }
        if (layout.containsKey("grow")) {
            attrs[TemplateKey.ATTR_FLEX_GROW] = plainNumber(layout.get("grow"), "$path.grow")
        }
        if (layout.containsKey("justify")) {
            attrs[TemplateKey.FLEXBOX_ATTR_JUSTIFY_CONTENT] = flexValue(
                layout.get("justify"),
                "$path.justify",
                justifyValues
            )
        }
        if (layout.containsKey("align")) {
            attrs[TemplateKey.FLEXBOX_ATTR_ALIGN_ITEMS] = enumValue(
                layout.get("align"),
                "$path.align",
                alignValues
            )
        }
    }

    private fun parsePadding(value: Any?, path: String, attrs: MutableMap<String, String>) {
        when (value) {
            is Number -> attrs[TemplateKey.ATTR_PADDING] = plainNumber(value, path)
            is JSONObject -> {
                requireKeys(
                    value,
                    path,
                    allowed = setOf("start", "end", "top", "bottom"),
                    required = emptySet()
                )
                if (value.isEmpty()) {
                    throw TemplateParseException("$path 不能是空对象")
                }
                putSide(value, "start", TemplateKey.ATTR_PADDING_START, path, attrs)
                putSide(value, "end", TemplateKey.ATTR_PADDING_END, path, attrs)
                putSide(value, "top", TemplateKey.ATTR_PADDING_TOP, path, attrs)
                putSide(value, "bottom", TemplateKey.ATTR_PADDING_BOTTOM, path, attrs)
            }
            else -> throw TemplateParseException("$path 必须是数字或四边对象")
        }
    }

    private fun putSide(
        source: JSONObject,
        key: String,
        attrName: String,
        path: String,
        attrs: MutableMap<String, String>
    ) {
        if (source.containsKey(key)) {
            attrs[attrName] = plainNumber(source.get(key), "$path.$key")
        }
    }

    private fun parseStyle(style: JSONObject, path: String, type: String, attrs: MutableMap<String, String>) {
        val allowed = linkedSetOf("background", "radius", "border")
        when (type) {
            "text" -> allowed.addAll(listOf("color", "fontSize", "align"))
            "input" -> allowed.addAll(listOf("color", "fontSize", "align", "hintColor"))
            "checkbox", "radio", "switch" -> allowed.addAll(listOf("color", "fontSize", "tint"))
            "progress" -> allowed.addAll(listOf("track", "bar"))
        }
        requireKeys(style, path, allowed, required = emptySet())
        if (style.isEmpty()) {
            throw TemplateParseException("$path 不能是空对象")
        }
        if (style.containsKey("background")) {
            attrs[TemplateKey.ATTR_BACKGROUND] = backgroundValue(style.get("background"), "$path.background")
        }
        if (style.containsKey("radius")) {
            parseRadius(style.get("radius"), "$path.radius", attrs)
        }
        if (style.containsKey("border")) {
            parseBorder(requireObject(style.get("border"), "$path.border"), "$path.border", attrs)
        }
        if (style.containsKey("color")) {
            attrs[TemplateKey.ATTR_TEXT_COLOR] = colorValue(style.get("color"), "$path.color")
        }
        if (style.containsKey("fontSize")) {
            attrs[TemplateKey.ATTR_TEXT_SIZE] = plainNumber(style.get("fontSize"), "$path.fontSize")
        }
        if (style.containsKey("align")) {
            val align = requireString(style.get("align"), "$path.align")
            if (align !in textAlignValues) {
                throw TemplateParseException("$path.align 只能是 start、center、end")
            }
            attrs[TemplateKey.ATTR_TEXT_ALIGN] = align
        }
        if (style.containsKey("hintColor")) {
            attrs[TemplateKey.ATTR_HINT_COLOR] = colorValue(style.get("hintColor"), "$path.hintColor")
        }
        if (style.containsKey("tint")) {
            attrs[TemplateKey.ATTR_TINT] = colorValue(style.get("tint"), "$path.tint")
        }
        if (style.containsKey("track")) {
            attrs[TemplateKey.ATTR_STROKE_COLOR] = paintValue(style.get("track"), "$path.track")
        }
        if (style.containsKey("bar")) {
            attrs[TemplateKey.ATTR_TRAIL_COLOR] = paintValue(style.get("bar"), "$path.bar")
        }
    }

    private fun parseRadius(value: Any?, path: String, attrs: MutableMap<String, String>) {
        when (value) {
            is Number -> attrs[TemplateKey.ATTR_RADIUS] = plainNumber(value, path)
            is JSONObject -> {
                requireKeys(
                    value,
                    path,
                    allowed = setOf("topStart", "topEnd", "bottomEnd", "bottomStart"),
                    required = emptySet()
                )
                if (value.isEmpty()) {
                    throw TemplateParseException("$path 不能是空对象")
                }
                putSide(value, "topStart", TemplateKey.ATTR_LEFT_TOP_RADIUS, path, attrs)
                putSide(value, "topEnd", TemplateKey.ATTR_RIGHT_TOP_RADIUS, path, attrs)
                putSide(value, "bottomEnd", TemplateKey.ATTR_RIGHT_BOTTOM_RADIUS, path, attrs)
                putSide(value, "bottomStart", TemplateKey.ATTR_LEFT_BOTTOM_RADIUS, path, attrs)
            }
            else -> throw TemplateParseException("$path 必须是数字或四角对象")
        }
    }

    private fun parseBorder(border: JSONObject, path: String, attrs: MutableMap<String, String>) {
        requireKeys(border, path, allowed = setOf("color", "width"), required = setOf("color", "width"))
        attrs[TemplateKey.ATTR_BORDER_COLOR] = colorValue(border.get("color"), "$path.color")
        attrs[TemplateKey.ATTR_BORDER_WIDTH] = plainNumber(border.get("width"), "$path.width")
    }

    private fun parseListFields(node: JSONObject, path: String, attrs: MutableMap<String, String>) {
        val data = requireString(node.get("data"), "$path.data")
        if (!data.startsWith("$")) {
            throw TemplateParseException("$path.data 必须是 \$ 开头的表达式")
        }
        attrs[TemplateKey.ATTR_DATA] = data
        val direction = if (node.containsKey("direction")) {
            requireString(node.get("direction"), "$path.direction")
        } else {
            "vertical"
        }
        if (direction != "horizontal" && direction != "vertical") {
            throw TemplateParseException("$path.direction 只能是 horizontal 或 vertical")
        }
        attrs[TemplateKey.ATTR_LIST_DIRECTION] = direction
        if (node.containsKey("gap")) {
            attrs[TemplateKey.ATTR_ITEM_PADDING] = plainNumber(node.get("gap"), "$path.gap")
        }
    }

    private fun parseProgressFields(node: JSONObject, path: String, attrs: MutableMap<String, String>) {
        if (node.containsKey("from")) {
            attrs[TemplateKey.ATTR_VALUE_MIN] = fractionValue(node.get("from"), "$path.from")
        }
        if (node.containsKey("to")) {
            attrs[TemplateKey.ATTR_VALUE_MAX] = fractionValue(node.get("to"), "$path.to")
        }
        if (node.containsKey("animate")) {
            attrs[TemplateKey.ATTR_ANIMATE_ENABLE] = boolString(node.get("animate"), "$path.animate")
        }
    }

    private fun parseInputFields(node: JSONObject, path: String, attrs: MutableMap<String, String>) {
        if (node.containsKey("value")) {
            attrs[TemplateKey.ATTR_TEXT] = requireString(node.get("value"), "$path.value")
        }
        if (node.containsKey("hint")) {
            attrs[TemplateKey.ATTR_HINT] = requireString(node.get("hint"), "$path.hint")
        }
        val keyboard = if (node.containsKey("keyboard")) {
            requireString(node.get("keyboard"), "$path.keyboard")
        } else {
            "text"
        }
        if (keyboard !in keyboardValues) {
            throw TemplateParseException("$path.keyboard 只能是 text、number、password、email、phone")
        }
        attrs[TemplateKey.ATTR_INPUT_TYPE] = keyboard
        if (node.containsKey("maxLength")) {
            attrs[TemplateKey.ATTR_MAX_LENGTH] = nonNegativeInt(node.get("maxLength"), "$path.maxLength")
        }
    }

    private fun parseCheckBoxFields(node: JSONObject, path: String, attrs: MutableMap<String, String>) {
        attrs[TemplateKey.ATTR_CHECKED] = if (node.containsKey("checked")) {
            checkedValue(node.get("checked"), "$path.checked")
        } else {
            "false"
        }
        if (node.containsKey("label")) {
            attrs[TemplateKey.ATTR_TEXT] = requireString(node.get("label"), "$path.label")
        }
    }

    private fun parseRadioFields(node: JSONObject, path: String, attrs: MutableMap<String, String>) {
        parseCheckBoxFields(node, path, attrs)
        attrs[TemplateKey.ATTR_GROUP] = groupValue(node.get("group"), "$path.group")
    }

    private fun parseLottieFields(node: JSONObject, path: String, attrs: MutableMap<String, String>) {
        attrs[TemplateKey.ATTR_ANIMATION_SRC] = requireString(node.get("src"), "$path.src")
        attrs[TemplateKey.ATTR_ANI_REPEAT_COUNT] = if (node.containsKey("repeat")) {
            repeatValue(node.get("repeat"), "$path.repeat")
        } else {
            "infinite"
        }
        attrs[TemplateKey.ATTR_ANI_REPEAT_MODE] = if (node.containsKey("mode")) {
            val mode = requireString(node.get("mode"), "$path.mode")
            if (mode != "restart" && mode != "reverse") {
                throw TemplateParseException("$path.mode 只能是 restart 或 reverse")
            }
            mode
        } else {
            "restart"
        }
        attrs[TemplateKey.ATTR_ANI_AUTO_PLAY] = if (node.containsKey("autoPlay")) {
            boolString(node.get("autoPlay"), "$path.autoPlay")
        } else {
            "true"
        }
    }

    private fun parseNames(value: Any?, path: String): List<String> {
        val array = requireArray(value, path)
        return array.mapIndexed { index, item ->
            requireName(item, "$path[$index]")
        }
    }

    private fun sizeValue(value: Any?, path: String): String {
        return when (value) {
            is Number -> plainNumber(value, path)
            is String -> when (value) {
                "fill" -> TemplateKey.OT_MATCH_PARENT
                "wrap" -> TemplateKey.OT_WRAP_CONTENT
                else -> throw TemplateParseException("$path 只能是数字、fill 或 wrap")
            }
            else -> throw TemplateParseException("$path 只能是数字、fill 或 wrap")
        }
    }

    private fun backgroundValue(value: Any?, path: String): String {
        return when (value) {
            is String -> colorValue(value, path)
            is JSONObject -> {
                requireKeys(
                    value,
                    path,
                    allowed = setOf("direction", "colors"),
                    required = setOf("direction", "colors")
                )
                val direction = enumValue(value.get("direction"), "$path.direction", gradientDirections)
                val colors = requireArray(value.get("colors"), "$path.colors")
                if (colors.size < 2) {
                    throw TemplateParseException("$path.colors 至少要有两个颜色")
                }
                val colorList = colors.mapIndexed { index, color ->
                    colorValue(color, "$path.colors[$index]")
                }
                "linear-gradient($direction, ${colorList.joinToString(", ")})"
            }
            else -> throw TemplateParseException("$path 必须是颜色或渐变对象")
        }
    }

    private fun paintValue(value: Any?, path: String): String {
        return when (value) {
            is JSONObject -> backgroundValue(value, path)
            else -> colorValue(value, path)
        }
    }

    private fun colorValue(value: Any?, path: String): String {
        val color = requireString(value, path)
        if (color == "transparent" || color.startsWith("$") || colorPattern.matches(color)) {
            return color
        }
        throw TemplateParseException("$path 必须是 #RGB、#RRGGBB、#AARRGGBB、transparent，或以 \$ 开头")
    }

    private fun fractionValue(value: Any?, path: String): String {
        return when (value) {
            is Number -> plainNumber(value, path)
            is String -> {
                if (value.startsWith("$") || value.toDoubleOrNull() != null) {
                    value
                } else {
                    throw TemplateParseException("$path 必须是数字或以 \$ 开头")
                }
            }
            else -> throw TemplateParseException("$path 必须是数字或以 \$ 开头")
        }
    }

    private fun repeatValue(value: Any?, path: String): String {
        return when (value) {
            is String -> {
                if (value == "infinite") {
                    value
                } else {
                    throw TemplateParseException("$path 只能是 infinite 或非负整数")
                }
            }
            is Number -> {
                val number = plainNumber(value, path)
                if (number.contains(".")) {
                    throw TemplateParseException("$path 只能是 infinite 或非负整数")
                }
                number
            }
            else -> throw TemplateParseException("$path 只能是 infinite 或非负整数")
        }
    }

    private fun enumValue(value: Any?, path: String, mapping: Map<String, String>): String {
        val name = requireString(value, path)
        return mapping[name] ?: throw TemplateParseException("$path「$name」不在允许的取值里")
    }

    private fun flexValue(value: Any?, path: String, mapping: Map<String, String>): String {
        val name = requireString(value, path)
        if (name.startsWith("$")) {
            return name
        }
        return mapping[name] ?: throw TemplateParseException("$path「$name」不在允许的取值里")
    }

    private fun targetList(value: Any?, path: String): List<String> {
        val names = when (value) {
            is JSONArray -> value.mapIndexed { index, item ->
                requireName(item, "$path[$index]")
            }
            else -> listOf(requireName(value, path))
        }
        if (names.isEmpty()) {
            throw TemplateParseException("$path 不能是空数组")
        }
        return names
    }

    private fun plainNumber(value: Any?, path: String): String {
        val number = value as? Number ?: throw TemplateParseException("$path 必须是数字")
        val decimal = when (number) {
            is BigDecimal -> number
            else -> BigDecimal(number.toString())
        }
        if (decimal.signum() < 0) {
            throw TemplateParseException("$path 不能是负数")
        }
        return decimal.stripTrailingZeros().toPlainString()
    }

    private fun boolString(value: Any?, path: String): String {
        val bool = value as? Boolean ?: throw TemplateParseException("$path 必须是布尔值")
        return bool.toString()
    }

    private fun groupValue(value: Any?, path: String): String {
        val name = requireString(value, path)
        if (name.startsWith("$") || namePattern.matches(name)) {
            return name
        }
        throw TemplateParseException("$path「$name」必须是字母或下划线开头的标识符，或以 \$ 开头")
    }

    private fun checkedValue(value: Any?, path: String): String {
        return when (value) {
            is Boolean -> value.toString()
            is String -> if (value.startsWith("$")) {
                value
            } else {
                throw TemplateParseException("$path 必须是布尔值或以 \$ 开头")
            }
            else -> throw TemplateParseException("$path 必须是布尔值或以 \$ 开头")
        }
    }

    private fun nonNegativeInt(value: Any?, path: String): String {
        val number = plainNumber(value, path)
        if (number.contains('.')) {
            throw TemplateParseException("$path 只能是非负整数")
        }
        return number
    }

    private fun requireObject(value: Any?, path: String): JSONObject {
        return value as? JSONObject ?: throw TemplateParseException("$path 必须是对象")
    }

    private fun requireArray(value: Any?, path: String): JSONArray {
        return value as? JSONArray ?: throw TemplateParseException("$path 必须是数组")
    }

    private fun requireString(value: Any?, path: String): String {
        return value as? String ?: throw TemplateParseException("$path 必须是字符串")
    }

    private fun requireName(value: Any?, path: String): String {
        val name = requireString(value, path)
        if (!namePattern.matches(name)) {
            throw TemplateParseException("$path「$name」必须是字母或下划线开头的标识符")
        }
        return name
    }

    private fun requireKeys(
        node: JSONObject,
        path: String,
        allowed: Set<String>,
        required: Set<String>
    ) {
        node.keys.forEach { key ->
            if (key !in allowed) {
                throw TemplateParseException("$path.$key 不是这里能写的字段")
            }
        }
        required.forEach { key ->
            if (!node.containsKey(key)) {
                throw TemplateParseException("$path 缺少 $key")
            }
        }
    }

    private fun jsonObject(vararg pairs: Pair<String, Any>): JSONObject {
        return JSONObject().apply {
            pairs.forEach { (key, value) -> put(key, value) }
        }
    }
}
