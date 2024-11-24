/*
 * Copyright (c) 2021, Alibaba Group Holding Limited;
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.dynamic.otter.template

import android.content.res.Resources
import android.util.TypedValue
import app.visly.stretch.Dimension
import com.dynamic.otter.ExpansionCenter
import com.dynamic.otter.OTEngine
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.utils.ScreenUtils

import kotlin.math.roundToInt

/**
 * @suppress
 */
sealed class OTSize {

    companion object {

        fun create(targetSize: String): OTSize {
            val value = targetSize.trim()
            return when {
                value.endsWith(TemplateKey.OT_PX) -> PX(value, convertPx(value))
                value.endsWith(TemplateKey.OT_PT) -> PT(value, convertPT(value))
                value.endsWith(TemplateKey.OT_PE) -> PE(value, convertPE(value))
                value == TemplateKey.OT_WRAP_CONTENT-> Auto
                value == TemplateKey.OT_MATCH_PARENT-> PE("match_parent", convertPE("100%"))
                value.isNotBlank() -> {
                    // 先判断是否可以转化为数字，如果可以，那么直接转换
                    value.toFloatOrNull()?.let {
                        return PX(value, it.dpToPx())
                    }

                    // 桥接到外部处理
                    ExpansionCenter.instance.extensionSize?.create(value)?.let {
                        return PX(value, it)
                    }

                    // 返回未定义
                    return Undefined
                }
                else -> Undefined
            }
        }

        private fun convertPT(value: String) = value.replacePtToEmpty().toFloat()

        private fun convertPE(value: String) = value.replacePeToEmpty().toFloat() / 100F

        private fun convertPx(value: String) = value.replacePxToEmpty().toFloat().dpToPx()

        fun Float.dpToPx(): Float {
            return (TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                this,
                Resources.getSystem().displayMetrics
            )).roundToInt().toFloat()
        }

        fun Float.ptToPx(): Float {
            val screenWidthPx = ScreenUtils.getScreenWidthPx(OTEngine.instance.context)
            val screenHeightPx = ScreenUtils.getScreenHeightPx(OTEngine.instance.context)
            val dpToPx = 375F.dpToPx()
            var ratio = (Math.min(screenWidthPx, screenHeightPx)) / dpToPx
            ExpansionCenter.instance.extensionSize?.convert(ratio)?.let {
                ratio = it
            }
            return (this.dpToPx() * Math.max(ratio, 1F)).roundToInt().toFloat()
        }

        private fun String.replacePxToEmpty(): String {
            return this.substring(0, length - TemplateKey.OT_PX.length)
        }

        private fun String.replacePtToEmpty(): String {
            return this.substring(0, length - TemplateKey.OT_PT.length)
        }

        private fun String.replacePeToEmpty(): String {
            return this.substring(0, length - TemplateKey.OT_PE.length)
        }
    }

    val name: String
        get() = when (this) {
            is PX -> targetName
            is PE -> targetName
            is PT -> targetName
            is Auto -> "Auto"
            is Undefined -> "Undefined"
        }

    val valueDimension: Dimension
        get() = when (this) {
            is PX -> Dimension.Points(targetValue)
            is PE -> Dimension.Percent(targetValue)
            is PT -> Dimension.Points(targetValue.ptToPx())
            is Auto -> Dimension.Auto
            is Undefined -> Dimension.Undefined
        }

    val valueInt: Int
        get() = when (this) {
            is PX -> targetValue.toInt()
            is PE -> targetValue.toInt()
            is PT -> targetValue.ptToPx().toInt()
            else -> 0
        }

    val valueFloat: Float
        get() = when (this) {
            is PX -> targetValue
            is PE -> targetValue
            is PT -> targetValue.ptToPx()
            else -> 0F
        }

    data class PX(val targetName: String, val targetValue: Float) : OTSize()

    data class PE(val targetName: String, val targetValue: Float) : OTSize()

    data class PT(val targetName: String, val targetValue: Float) : OTSize()

    object Auto : OTSize()

    object Undefined : OTSize()
}
