package com.dynamic.otter.data

object TemplateKey {
    // root node name
    const val LAYOUT_ROOT_NAME = "Layout"
    const val EVENTS_ROOT_NAME = "Events"
    const val LAYOUT_ITEM = "Item"
    // 用于保存页面DSL上的id和通过View生成的id的对应关系，需要将View生成的ID设置给View
    // 并且将其和DSL中定义的ID做一一映射，这样就可以在绑定事件的时候通过ID 获取到对应的View了
    val RMap: MutableMap<String, Int> = mutableMapOf()

    // view node name key
    const val COLUMN = "Column"
    const val ROW = "Row"
    const val TEXT = "Text"
    const val IMAGE = "Image"
    const val CUSTOM = "Custom"
    const val SPACER = "Spacer"
    const val OT_LIST = "OTList"
    const val PROGRESS = "Progress"
    const val ANIMATION = "Animation"

    // function
    const val ATTR_FUN_ID = "funId"

    // common attribute
    const val ATTR_ID = "id"
    const val ATTR_RADIUS = "radius"
    const val ATTR_WIDTH = "width"
    const val ATTR_HEIGHT = "height"
    const val ATTR_BACKGROUND = "background"
    const val ATTR_ONCLICK = "onClick"

    const val ATTR_LEFT_TOP_RADIUS = "leftTopRadius"
    const val ATTR_LEFT_BOTTOM_RADIUS = "leftBottomRadius"
    const val ATTR_RIGHT_TOP_RADIUS = "rightTopRadius"
    const val ATTR_RIGHT_BOTTOM_RADIUS = "rightBottomRadius"

    const val ATTR_BORDER_COLOR = "borderColor"
    const val ATTR_BORDER_WIDTH = "borderWidth"

    const val ATTR_PADDING = "padding"
    const val ATTR_PADDING_START = "paddingStart"
    const val ATTR_PADDING_END = "paddingEnd"
    const val ATTR_PADDING_TOP = "paddingTop"
    const val ATTR_PADDING_BOTTOM = "paddingBottom"


    const val OT_WRAP_CONTENT = "wrap_content"
    const val OT_MATCH_PARENT = "match_parent"

    // Image attribute
    const val ATTR_SRC = "src"
    const val ATTR_PLACEHOLDER = "placeholder"

    // Text attribute
    const val ATTR_TEXT = "text"
    const val ATTR_TEXT_COLOR = "textColor"
    const val ATTR_TEXT_SIZE = "textSize"
    const val ATTR_TEXT_ALIGN = "textAlign"
    const val ATTR_INCLUDE_FONT_PADDING = "includeFontPadding"

    // ColumnList attribute
    const val ATTR_DATA = "data"
    const val ATTR_LIST_DIRECTION = "listDirection"
    const val OT_HORIZONTAL = "horizontal"
    const val OT_VERTICAL = "vertical"
    const val ATTR_ITEM_PADDING = "itemPadding"

    // progress attribute
    const val ATTR_TRAIL_COLOR = "trailColor"
    const val ATTR_STROKE_COLOR = "strokeColor"
    const val ATTR_VALUE_MIN = "valueMin"
    const val ATTR_VALUE_MAX = "valueMax"
    const val ATTR_ANIMATE_ENABLE = "animateEnable"


    // animation attribute
    const val ATTR_ANIMATION_SRC = "animationSrc"
    const val ATTR_ANI_REPEAT_COUNT = "repeatCount"
    const val ATTR_ANI_REPEAT_MODE = "repeatMode"
    const val ATTR_ANI_AUTO_PLAY = "autoPlay"

    // unit
    const val OT_PX = "px"
    const val OT_PT = "pt"
    const val OT_PE = "%"


    // flexbox attribute
    const val FLEXBOX_ATTR_JUSTIFY_CONTENT = "justifyContent"
    const val FLEXBOX_ATTR_ALIGN_ITEMS = "alignItems"


}