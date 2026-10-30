package com.dynamic.otter.render.view

import android.graphics.Color
import android.graphics.Outline
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.view.ViewOutlineProvider
import com.dynamic.otter.data.OTHelper
import com.dynamic.otter.render.view.attr.ViewAttr
import com.dynamic.otter.render.view.basic.Text
import com.dynamic.otter.render.view.basic.capability.ICornerRoundConfigCapability
import com.dynamic.otter.render.view.drawable.ColorGradientDrawable
import com.dynamic.otter.render.view.drawable.LinearColorGradientDrawable
import com.dynamic.otter.template.OTLinearColor
import com.dynamic.otter.template.OTSize
import com.dynamic.otter.template.StyleConverter

fun View.applyUniformCornerOutline(radius: Float) {
    clipToOutline = true
    outlineProvider = object : ViewOutlineProvider() {
        override fun getOutline(view: View, outline: Outline) {
            if (alpha >= 0.0f) {
                outline.alpha = alpha
            }
            outline.setRoundRect(0, 0, view.width, view.height, radius)
        }
    }
}

fun View.setViewRoundCornerAndBorder(viewAttr: ViewAttr?) {
    if (this !is ICornerRoundConfigCapability) {
        return
    }
    val radiusArr = viewAttr?.let { StyleConverter.borderRadius(it)?.value } ?: return
    configureViewRoundCorner(radiusArr)
    val borderWidth = viewAttr.borderWidth?.let { OTSize.create(it).valueFloat }
    val borderColor = viewAttr.borderColor
    if (borderColor != null && borderWidth != null) {
        configureViewRoundCornerBorder(Color.parseColor(borderColor), borderWidth, radiusArr)
    }
}

fun View.setBackgroundWithRadius(viewAttr: ViewAttr?) {
    val viewBackground = viewAttr?.background.orEmpty()
    if (viewBackground.startsWith("linear-gradient")) {
        if (this !is Text) {
            background = StyleConverter.backgroundLinearColor(viewBackground)?.createDrawable()
        }
    } else if (!OTHelper.isNetSrc(viewBackground) && !OTHelper.isResSrc(viewBackground)) {
        background = StyleConverter.backgroundColor(viewAttr?.background)?.createBackgroundColorDrawable()
    }

    if (background is ColorGradientDrawable || background is LinearColorGradientDrawable) {
        (background as GradientDrawable).cornerRadii = viewAttr?.let { StyleConverter.borderRadius(it)?.value }
    }
}

fun Text.setTextBackground(backgroundDrawable: OTLinearColor?) {
    if (backgroundDrawable != null) {
        this.setTextColor(Color.BLACK) // default Color is black
        this.paint.shader = backgroundDrawable.createShader(this)
    }
}

fun Text.setTextAlign(alignStr: String) {
    val textAlign = StyleConverter.textAlign(alignStr)
    if (textAlign != null) {
        this.gravity = Gravity.CENTER_VERTICAL.or(textAlign)
    } else {
        this.gravity = Gravity.CENTER_VERTICAL.or(Gravity.LEFT)
    }
}

