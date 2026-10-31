package com.dynamic.otter.render.view.basic

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.util.AttributeSet
import android.util.TypedValue
import android.view.Gravity
import androidx.annotation.Keep
import com.dynamic.otter.render.view.applyUniformCornerOutline
import com.dynamic.otter.render.view.attr.SwitchAttr
import com.dynamic.otter.render.view.attr.ViewAttr
import com.dynamic.otter.render.view.basic.capability.ICheckable
import com.dynamic.otter.render.view.basic.capability.ICornerRoundConfigCapability
import com.dynamic.otter.render.view.basic.capability.IStyleBindingCapability
import com.dynamic.otter.template.OTColor
import com.dynamic.otter.template.OTSize
import com.dynamic.otter.template.StyleConverter
import com.google.android.material.materialswitch.MaterialSwitch

@Keep
class Switch : MaterialSwitch, ICheckable, IStyleBindingCapability, ICornerRoundConfigCapability {
    constructor(context: Context) : super(context)
    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs)
    constructor(context: Context, attrs: AttributeSet?, defStyle: Int) : super(
        context,
        attrs,
        defStyle
    )

    init {
        gravity = Gravity.CENTER_VERTICAL
        includeFontPadding = false
        showText = false
        textOn = ""
        textOff = ""
        splitTrack = false
    }

    override fun onBindData(data: Any?) {
        val checked = when (data) {
            is Boolean -> data
            is String -> data == "true"
            else -> return
        }
        setCheckedSilently(checked)
    }

    override fun onBindStyle(attr: ViewAttr, attrData: Any?) {
        if (attr !is SwitchAttr) {
            return
        }
        applyTextSize(attr.textSize)
        includeFontPadding = false
        setTextColor(colorOrDefault(attr.textColor, "#1F1A17"))
        val tint = colorOrDefault(attr.tint, "#1F6F6A")
        val restingThumb = Color.argb(0xFF, 0xF3, 0xEF, 0xE7)
        val restingTrack = Color.argb(0x33, 0x1F, 0x1A, 0x17)
        val activeTrack = Color.argb(0x66, Color.red(tint), Color.green(tint), Color.blue(tint))
        thumbTintList = ColorStateList(
            arrayOf(intArrayOf(android.R.attr.state_checked), intArrayOf()),
            intArrayOf(tint, restingThumb)
        )
        trackTintList = ColorStateList(
            arrayOf(intArrayOf(android.R.attr.state_checked), intArrayOf()),
            intArrayOf(activeTrack, restingTrack)
        )
        applyPadding(attr)
        applyLabel(attr.text, attr.checked)
    }

    override fun configureViewRoundCorner(radius: FloatArray) {
        if (radius.size != 8) {
            return
        }
        val uniform = radius[0]
        val sameCorner = radius[2] == uniform && radius[4] == uniform && radius[6] == uniform
        if (sameCorner && uniform > 0) {
            applyUniformCornerOutline(uniform)
        } else {
            clipToOutline = false
            outlineProvider = null
        }
    }

    override fun configureViewRoundCornerBorder(
        borderColor: Int,
        borderWidth: Float,
        radius: FloatArray
    ) {
        if (borderWidth > 0) {
            setPadding(
                borderWidth.toInt(),
                borderWidth.toInt(),
                borderWidth.toInt(),
                borderWidth.toInt()
            )
        }
        if (background == null) {
            val target = GradientDrawable()
            target.shape = GradientDrawable.RECTANGLE
            target.cornerRadii = radius
            target.setStroke(borderWidth.toInt(), borderColor)
            background = target
        } else if (background is GradientDrawable) {
            val target = background as GradientDrawable
            target.setStroke(borderWidth.toInt(), borderColor)
            target.cornerRadii = radius
        }
    }

    private fun setCheckedSilently(checked: Boolean) {
        setOnCheckedChangeListener(null)
        isChecked = checked
    }

    private fun applyLabel(label: String, checked: Boolean) {
        setCheckedSilently(checked)
        text = label
        if (label.isNotEmpty()) {
            contentDescription = label
        }
    }

    private fun applyTextSize(rawSize: String) {
        setTextSize(TypedValue.COMPLEX_UNIT_PX, OTSize.create(rawSize).valueFloat)
    }

    private fun applyPadding(attr: ViewAttr) {
        val padding = StyleConverter.padding(attr)
        setPadding(
            padding?.start?.valueInt ?: 0,
            padding?.top?.valueInt ?: 0,
            padding?.end?.valueInt ?: 0,
            padding?.bottom?.valueInt ?: 0
        )
    }

    private fun colorOrDefault(raw: String, fallback: String): Int {
        return OTColor.create(raw)?.value() ?: Color.parseColor(fallback)
    }
}
