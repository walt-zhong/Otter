package com.dynamic.otter.template

import app.visly.stretch.AlignItems
import app.visly.stretch.Display
import app.visly.stretch.FlexDirection
import app.visly.stretch.JustifyContent
import com.dynamic.otter.data.FlexBoxKey

object FlexBoxConvert {
    fun flexDirection(target:String) = when(target){
        FlexBoxKey.FLEXBOX_ROW -> FlexDirection.Row
        FlexBoxKey.FLEXBOX_COLUMN -> FlexDirection.Column
        FlexBoxKey.FLEXBOX_COLUMN_REVERSE -> FlexDirection.ColumnReverse
        FlexBoxKey.FLEXBOX_ROW_REVERSE -> FlexDirection.RowReverse
        else -> null
    }

    fun display(target: String):Display? = when(target){
        FlexBoxKey.FLEXBOX_FLEX->Display.Flex
        FlexBoxKey.FLEXBOX_NONE->Display.None
        else->null
    }

    fun justifyContent(target: String): JustifyContent? = when (target) {
        "start" -> JustifyContent.FlexStart
        "end" -> JustifyContent.FlexEnd
        "center" -> JustifyContent.Center
        "space-around" -> JustifyContent.SpaceAround
        "space-between" -> JustifyContent.SpaceBetween
        "space-evenly" -> JustifyContent.SpaceEvenly
        else -> null
    }

    fun alignItems(target: String): AlignItems? = when (target) {
        "start" -> AlignItems.FlexStart
        "end" -> AlignItems.FlexEnd
        "center" -> AlignItems.Center
        "baseline" -> AlignItems.Baseline
        "stretch" -> AlignItems.Stretch
        else -> null
    }
}