package com.dynamic.otter.render.view.basic

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.util.AttributeSet
import android.util.TypedValue
import android.view.Gravity
import android.widget.CompoundButton
import androidx.annotation.Keep
import androidx.appcompat.widget.AppCompatCheckBox
import androidx.core.widget.CompoundButtonCompat
import com.dynamic.otter.render.view.applyUniformCornerOutline
import com.dynamic.otter.render.view.attr.CheckBoxAttr
import com.dynamic.otter.render.view.attr.ViewAttr
import com.dynamic.otter.render.view.basic.capability.ICheckable
import com.dynamic.otter.render.view.basic.capability.ICornerRoundConfigCapability
import com.dynamic.otter.render.view.basic.capability.IStyleBindingCapability
import com.dynamic.otter.template.OTColor
import com.dynamic.otter.template.OTSize
import com.dynamic.otter.template.StyleConverter

@Keep
class CheckBox : AppCompatCheckBox, ICheckable, IStyleBindingCapability,
    ICornerRoundConfigCapability {

    private var checkedChangeListener: CompoundButton.OnCheckedChangeListener? = null

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
    }

    override fun onBindData(data: Any?) {
        val checked = when (data) {
            is Boolean -> data
            is String -> data == "true"
            else -> return
        }
        setOnCheckedChangeListener(null)
        isChecked = checked
        setOnCheckedChangeListener(checkedChangeListener)
    }

    override fun onBindStyle(attr: ViewAttr, attrData: Any?) {
        if (attr !is CheckBoxAttr) {
            return
        }
        applyTextSize(attr.textSize)
        includeFontPadding = false
        setTextColor(colorOrDefault(attr.textColor, "#1F1A17"))
        val tint = colorOrDefault(attr.tint, "#1F6F6A")
        val resting = Color.argb(0x8A, Color.red(tint), Color.green(tint), Color.blue(tint))
        CompoundButtonCompat.setButtonTintList(
            this,
            ColorStateList(
                arrayOf(intArrayOf(android.R.attr.state_checked), intArrayOf()),
                intArrayOf(tint, resting)
            )
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

    private fun applyLabel(label: String, checked: Boolean) {
        setOnCheckedChangeListener(null)
        text = label
        isChecked = checked
        if (label.isNotEmpty()) {
            contentDescription = label
        }
        setOnCheckedChangeListener(checkedChangeListener)
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
