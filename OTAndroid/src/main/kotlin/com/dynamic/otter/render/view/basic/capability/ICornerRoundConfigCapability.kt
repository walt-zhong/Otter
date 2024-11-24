package com.dynamic.otter.render.view.basic.capability

interface ICornerRoundConfigCapability {
    fun configureViewRoundCorner(radius:FloatArray)
    fun configureViewRoundCornerBorder(borderColor:Int,borderWidth:Float,radius: FloatArray)
}