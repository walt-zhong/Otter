package com.dynamic.otter.template

class OTRoundCorner(
    var leftTopRadius: OTSize?,
    var rightTopRadius: OTSize?,
    var leftBottomRadius: OTSize?,
    var rightBottomRadius: OTSize?
) {
    private fun toFloatArray(): FloatArray {
        val radiusArr = FloatArray(8)
        val lt = leftTopRadius?.valueFloat ?: 0F
        val rt = rightTopRadius?.valueFloat ?: 0F
        val lb = leftBottomRadius?.valueFloat ?: 0F
        val rb = rightBottomRadius?.valueFloat ?: 0F

        radiusArr[0] = lt
        radiusArr[1] = lt
        radiusArr[2] = rt
        radiusArr[3] = rt

        radiusArr[4] = rb
        radiusArr[5] = rb
        radiusArr[6] = lb
        radiusArr[7] = lb

        return radiusArr
    }

    val value: FloatArray
        get() {
            return toFloatArray()
        }
}