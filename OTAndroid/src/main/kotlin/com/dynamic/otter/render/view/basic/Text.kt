package com.dynamic.otter.render.view.basic

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.util.AttributeSet
import android.util.TypedValue
import androidx.annotation.Keep
import androidx.appcompat.widget.AppCompatTextView
import app.visly.stretch.Rect
import com.alibaba.fastjson.JSONArray
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.expression.ExpressionWrapper
import com.dynamic.otter.render.view.attr.TextAttr
import com.dynamic.otter.render.view.attr.ViewAttr
import com.dynamic.otter.render.view.basic.capability.ICornerRoundConfigCapability
import com.dynamic.otter.render.view.basic.capability.IDataBindingCapability
import com.dynamic.otter.render.view.basic.capability.IReleaseCapability
import com.dynamic.otter.render.view.basic.capability.IStyleBindingCapability
import com.dynamic.otter.render.view.applyUniformCornerOutline
import com.dynamic.otter.render.view.setTextAlign
import com.dynamic.otter.render.view.setTextBackground
import com.dynamic.otter.template.OTColor
import com.dynamic.otter.template.OTSize
import com.dynamic.otter.template.StyleConverter

@Keep
class Text : AppCompatTextView, IDataBindingCapability, IReleaseCapability,
    IStyleBindingCapability, ICornerRoundConfigCapability {
    private var lastStartPadding: Int? = null
    private var lastEndPadding: Int? = null
    private var lastTopPadding: Int? = null
    private var lastBottomPadding: Int? = null

    constructor(context: Context) : super(context)
    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs)
    constructor(context: Context, attrs: AttributeSet?, defStyle: Int) : super(
        context,
        attrs,
        defStyle
    )

    override fun onBindData(data: Any?) {
        when (data) {
            is String -> this.text = data

            is JSONObject -> {
                updateStyleByJsonObj(data)
            }
        }
    }

    override fun onBindStyle(attr: ViewAttr,attrData:Any?) {
        if (attr is TextAttr) {
            updateStyleByAttr(attr)
        }
    }

    private fun updateStyleByAttr(attr: TextAttr) {
        applyTextSize(attr.textSize)
        setTextBackground(StyleConverter.backgroundLinearColor(attr.background))
        val textColor = OTColor.create(attr.textColor)?.value()
        // 因为背景边框的设置是依赖shader的所以设置前应该将shader置空
        paint.shader = null
        setTextColor(textColor ?: Color.BLACK)
        includeFontPadding = false
        //设置文本的对齐方式
        attr.textAlign?.let { setTextAlign(it) }
        setTextPadding(StyleConverter.padding(attr))
    }

    // OTSize 已把字号从 dp 换成 px。textSize 的 setter 会按 sp 再乘一次 density，字形会超出布局框。
    private fun applyTextSize(rawSize: String) {
        setTextSize(TypedValue.COMPLEX_UNIT_PX, OTSize.create(rawSize).valueFloat)
    }

    private fun setTextPadding(padding: Rect<OTSize?>?) {
        val startPadding = padding?.start?.valueInt ?: 0
        val endPadding = padding?.end?.valueInt ?: 0
        val topPadding = padding?.top?.valueInt ?: 0
        val bottomPadding = padding?.bottom?.valueInt ?: 0

        if (lastStartPadding != startPadding
            || lastTopPadding != topPadding
            || lastEndPadding != endPadding
            || lastBottomPadding != bottomPadding
        ) {
            this.setPadding(
                startPadding,
                topPadding,
                endPadding,
                bottomPadding
            )
        }

        lastStartPadding = startPadding
        lastEndPadding = endPadding
        lastTopPadding = topPadding
        lastBottomPadding = bottomPadding
    }

    private fun updateStyleByJsonObj(data: JSONObject) {
        // TODO：添加无障碍之类的描述
        val result = ExpressionWrapper.instance.getResult("\$attributes", data)
        if (result is JSONArray) {
            result.forEach { styleObj ->
                // 只处理数JSONArray中是JSONObject的情况
                if (styleObj is JSONObject) {
                    styleObj.keys.forEach { key ->
                        val value = ExpressionWrapper.instance.getResult("\$$key", styleObj)
                        when (key) {
                            TemplateKey.ATTR_TEXT_SIZE -> applyTextSize(value.toString())

                            TemplateKey.ATTR_TEXT_COLOR -> this.setTextColor(
                                Color.parseColor(
                                    value.toString()
                                )
                            )

                            TemplateKey.ATTR_TEXT -> text = value.toString()
                        }
                    }
                }
            }
        }
    }

    @SuppressLint("SetTextI18n")
    override fun release() {
        this.text = ""
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
            this.setPadding(
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

}