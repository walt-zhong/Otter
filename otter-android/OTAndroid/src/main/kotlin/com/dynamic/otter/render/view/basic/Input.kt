package com.dynamic.otter.render.view.basic

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.text.InputFilter
import android.text.InputType
import android.text.method.PasswordTransformationMethod
import android.util.AttributeSet
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.inputmethod.EditorInfo
import androidx.annotation.Keep
import androidx.appcompat.widget.AppCompatEditText
import com.alibaba.fastjson.JSONArray
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.nav.Ime
import com.dynamic.otter.expression.ExpressionWrapper
import com.dynamic.otter.render.view.applyUniformCornerOutline
import com.dynamic.otter.render.view.attr.InputAttr
import com.dynamic.otter.render.view.attr.ViewAttr
import com.dynamic.otter.render.view.basic.capability.ICornerRoundConfigCapability
import com.dynamic.otter.render.view.basic.capability.IDataBindingCapability
import com.dynamic.otter.render.view.basic.capability.IReleaseCapability
import com.dynamic.otter.render.view.basic.capability.IStyleBindingCapability
import com.dynamic.otter.render.view.setTextAlign
import com.dynamic.otter.template.OTColor
import com.dynamic.otter.template.OTSize
import com.dynamic.otter.template.StyleConverter

@Keep
class Input : AppCompatEditText, IDataBindingCapability, IReleaseCapability,
    IStyleBindingCapability, ICornerRoundConfigCapability {

    constructor(context: Context) : super(context)
    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs)
    constructor(context: Context, attrs: AttributeSet?, defStyle: Int) : super(
        context,
        attrs,
        defStyle
    )

    init {
        background = null
        includeFontPadding = false
        isSingleLine = true
        maxLines = 1
        gravity = Gravity.CENTER_VERTICAL or Gravity.START
        imeOptions = EditorInfo.IME_ACTION_DONE
        setOnEditorActionListener { _, actionId, _ ->
            if (actionId != EditorInfo.IME_ACTION_DONE) {
                return@setOnEditorActionListener false
            }
            Ime.dismiss(this)
            true
        }
    }

    override fun onBindData(data: Any?) {
        when (data) {
            is String -> {
                if (text?.toString() == data) {
                    return
                }
                setText(data)
                setSelection(text?.length ?: 0)
            }

            is JSONObject -> updateStyleByJsonObj(data)
        }
    }

    override fun onBindStyle(attr: ViewAttr, attrData: Any?) {
        if (attr !is InputAttr) {
            return
        }
        applyTextSize(attr.textSize)
        paint.shader = null
        setTextColor(colorOrDefault(attr.textColor, "#1F1A17"))
        hint = attr.hint
        setHintTextColor(colorOrDefault(attr.hintColor, "#8A8178"))
        applyKeyboard(attr.inputType, attr.lines)
        val align = attr.textAlign
        if (align != null) {
            setTextAlign(align)
        } else {
            gravity = if (attr.lines > 1) {
                Gravity.TOP or Gravity.START
            } else {
                Gravity.CENTER_VERTICAL or Gravity.START
            }
        }
        if (attr.lines > 1) {
            val horizontal = gravity and (
                Gravity.HORIZONTAL_GRAVITY_MASK or Gravity.RELATIVE_HORIZONTAL_GRAVITY_MASK
            )
            gravity = Gravity.TOP or (if (horizontal == 0) Gravity.START else horizontal)
        }
        val length = attr.maxLength?.toIntOrNull()
        filters = if (length != null && length >= 0) {
            arrayOf(InputFilter.LengthFilter(length))
        } else {
            emptyArray<InputFilter>()
        }
        applyPadding(attr)
        includeFontPadding = false
    }

    override fun release() {
        setText("")
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

    private var appliedKeyboard: String? = null

    private fun applyKeyboard(type: String, lines: Int) {
        val key = "$type:$lines"
        // setSingleLine / setInputType 会 restartInput。搜索每次按键都重绑，
        // 重复写键盘类型会把下一次退格丢掉，字母就没法连续删除。
        if (appliedKeyboard == key) {
            return
        }
        val multiline = lines > 1
        // setSingleLine 会改掉 inputType，必须先收成单行，再写键盘类型。
        if (!multiline) {
            isSingleLine = true
            maxLines = 1
        }
        var bits = when (type) {
            "number" -> InputType.TYPE_CLASS_NUMBER
            "password" -> InputType.TYPE_CLASS_TEXT or
                InputType.TYPE_TEXT_VARIATION_PASSWORD or
                InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
            "email" -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS
            "phone" -> InputType.TYPE_CLASS_PHONE
            else -> InputType.TYPE_CLASS_TEXT
        }
        if (multiline && (bits and InputType.TYPE_MASK_CLASS) == InputType.TYPE_CLASS_TEXT) {
            bits = bits or InputType.TYPE_TEXT_FLAG_MULTI_LINE
        }
        inputType = bits
        if (multiline) {
            isSingleLine = false
            maxLines = lines
            minLines = lines
            imeOptions = EditorInfo.IME_ACTION_NONE
        } else {
            imeOptions = EditorInfo.IME_ACTION_DONE
        }
        // setInputType / setSingleLine 会清掉 transformation，密码遮罩要在它们后面补上。
        transformationMethod = if (type == "password") {
            PasswordTransformationMethod.getInstance()
        } else {
            null
        }
        applyAutofill(type)
        appliedKeyboard = key
    }

    private fun applyAutofill(type: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val hint = when (type) {
            "email" -> View.AUTOFILL_HINT_EMAIL_ADDRESS
            "phone" -> View.AUTOFILL_HINT_PHONE
            "password" -> View.AUTOFILL_HINT_PASSWORD
            else -> null
        }
        importantForAutofill = if (hint == null) {
            View.IMPORTANT_FOR_AUTOFILL_NO
        } else {
            View.IMPORTANT_FOR_AUTOFILL_YES
        }
        setAutofillHints(*listOfNotNull(hint).toTypedArray())
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

    private fun updateStyleByJsonObj(data: JSONObject) {
        val result = ExpressionWrapper.instance.getResult("\$attributes", data)
        if (result is JSONArray) {
            result.forEach { styleObj ->
                if (styleObj is JSONObject) {
                    styleObj.keys.forEach { key ->
                        val value = ExpressionWrapper.instance.getResult("\$$key", styleObj)
                        when (key) {
                            TemplateKey.ATTR_TEXT_SIZE -> applyTextSize(value.toString())
                            TemplateKey.ATTR_TEXT_COLOR -> setTextColor(Color.parseColor(value.toString()))
                            TemplateKey.ATTR_TEXT -> {
                                val next = value.toString()
                                if (text?.toString() != next) {
                                    setText(next)
                                    setSelection(text?.length ?: 0)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
