package com.dynamic.otter.template

import app.visly.stretch.AlignItems
import app.visly.stretch.JustifyContent

object FlexBoxConvert {
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
