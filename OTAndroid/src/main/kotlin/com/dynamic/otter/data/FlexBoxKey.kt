package com.dynamic.otter.data

object FlexBoxKey {
    const val FLEXBOX_FLEX = "flex"
    const val FLEXBOX_NONE = "none"

    const val FLEXBOX_ROW = "row"
    const val FLEXBOX_COLUMN = "column"
    const val FLEXBOX_COLUMN_REVERSE = "column-reverse"
    const val FLEXBOX_ROW_REVERSE = "row-reverse"

    /**
     * 弹性容器通过设置 display 属性的值为 flex 或 inline-flex将其定义为弹性容器。
     */
    const val FLEXBOX_DISPLAY = "display"

    /**
     * 设置页面布局方式，如果我们设置 direction 属性为 rtl (right-to-left),弹性子元素的排列方式也会改变，页面布局也跟着改变:
     */
    const val FLEXBOX_DIRECTION = "direction"

    /**
     * flex-direction 属性指定了弹性子元素在父容器中的位置。
     */
    const val FLEXBOX_FLEX_DIRECTION = "flex-direction"

    /**
     * flex-wrap 属性用于指定弹性盒子的子元素换行方式。
     */
    const val FLEXBOX_FLEX_WRAP = "flex-wrap"

    /**
     * overflow 属性规定当内容溢出元素框时发生的事情。
     */
    const val FLEXBOX_OVERFLOW = "overflow"

    /**
     * align-items 设置或检索弹性盒子元素在侧轴（纵轴）方向上的对齐方式。
     */
    const val FLEXBOX_ALIGN_ITEMS = "align-items"

    /**
     * align-self 属性用于设置弹性元素自身在侧轴（纵轴）方向上的对齐方式。
     */
    const val FLEXBOX_ALIGN_SELF = "align-self"

    /**
     * align-content 属性用于修改 flex-wrap 属性的行为。类似于 align-items, 但它不是设置弹性子元素的对齐，而是设置各个行的对齐。
     */
    const val FLEXBOX_ALIGN_CONTENT = "align-content"

    /**
     * 内容对齐（justify-content）属性应用在弹性容器上，把弹性项沿着弹性容器的主轴线（main axis）对齐。
     */
    const val FLEXBOX_JUSTIFY_CONTENT = "justify-content"

    /**
     * 规定元素的定位类型。
     */
    const val FLEXBOX_POSITION_TYPE = "position"

    const val FLEXBOX_POSITION_LEFT = "left"

    const val FLEXBOX_POSITION_RIGHT = "right"

    const val FLEXBOX_POSITION_TOP = "top"

    const val FLEXBOX_POSITION_BOTTOM = "bottom"

    /**
     * 外边距属性。
     */
    const val FLEXBOX_MARGIN = "margin"

    const val FLEXBOX_MARGIN_LEFT = "margin-left"

    const val FLEXBOX_MARGIN_RIGHT = "margin-right"

    const val FLEXBOX_MARGIN_TOP = "margin-top"

    const val FLEXBOX_MARGIN_BOTTOM = "margin-bottom"

    /**
     * 内边距属性
     */
    const val FLEXBOX_PADDING = "padding"

    const val FLEXBOX_PADDING_LEFT = "padding-left"

    const val FLEXBOX_PADDING_RIGHT = "padding-right"

    const val FLEXBOX_PADDING_TOP = "padding-top"

    const val FLEXBOX_PADDING_BOTTOM = "padding-bottom"

    /**
     * 边框属性
     */
    const val FLEXBOX_BORDER = "border"

    const val FLEXBOX_BORDER_LEFT = "border-left"

    const val FLEXBOX_BORDER_RIGHT = "border-right"

    const val FLEXBOX_BORDER_TOP = "border-top"

    const val FLEXBOX_BORDER_BOTTOM = "border-bottom"

    /**
     * flex 属性用于指定弹性子元素如何分配空间。
     * [ flex-grow ]：定义弹性盒子元素的扩展比率。
     */
    const val FLEXBOX_FLEX_GROW = "flex-grow"

    /**
     * flex 属性用于指定弹性子元素如何分配空间。
     * [ flex-shrink ]：定义弹性盒子元素的收缩比率。
     */
    const val FLEXBOX_FLEX_SHRINK = "flex-shrink"

    /**
     * flex 属性用于指定弹性子元素如何分配空间。
     * [ flex-basis ]：定义弹性盒子元素的默认基准值。
     */
    const val FLEXBOX_FLEX_BASIS = "flex-basis"

    /**
     * 规定页面内容包含框的尺寸和方向。
     */
    const val FLEXBOX_SIZE = "size"

    const val FLEXBOX_MIN_SIZE = "min-size"

    const val FLEXBOX_MAX_SIZE = "max-size"

    const val FLEXBOX_SIZE_WIDTH = "width"

    const val FLEXBOX_SIZE_HEIGHT = "height"

    const val FLEXBOX_MIN_WIDTH = "min-width"

    const val FLEXBOX_MIN_HEIGHT = "min-height"

    const val FLEXBOX_MAX_WIDTH = "max-width"

    const val FLEXBOX_MAX_HEIGHT = "max-height"

}