package com.dynamic.otter.render.view

import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import com.dynamic.otter.data.OTHelper
import com.dynamic.otter.render.view.attr.ViewAttr
import com.dynamic.otter.render.view.basic.Column
import com.dynamic.otter.render.view.basic.Image
import com.dynamic.otter.render.view.basic.Row
import com.dynamic.otter.render.view.basic.Text
import com.dynamic.otter.render.view.basic.capability.ICornerRoundConfigCapability
import com.dynamic.otter.render.view.drawable.ColorGradientDrawable
import com.dynamic.otter.render.view.drawable.LinearColorGradientDrawable
import com.dynamic.otter.template.OTLinearColor
import com.dynamic.otter.template.OTSize
import com.dynamic.otter.template.StyleConverter

fun View.setViewRoundCornerAndBorder(viewAttr: ViewAttr?) {
    val radiusArr = viewAttr?.let { StyleConverter.instance.borderRadius(it)?.value }
    val borderWidth = viewAttr?.borderWidth?.let { OTSize.create(it).valueFloat }
    val borderColor = viewAttr?.borderColor

    if (this is ICornerRoundConfigCapability) {
        when (this) {
            is Image, is Text, is Column, is Row -> {
                if (radiusArr != null) {
                    this.configureViewRoundCorner(radiusArr)
                    if (borderColor != null && borderWidth != null) {
                        this.configureViewRoundCornerBorder(
                            Color.parseColor(borderColor),
                            borderWidth,
                            radiusArr
                        )
                    }
                }
            }
        }
    }
}

fun View.setBackgroundWithRadius(viewAttr: ViewAttr?) {
    // linear-gradient(to bottom,  #8b572a 0%,#f5a623 100%);
    // 如果是线性渐变背景
    val viewBackground = viewAttr?.background ?: ""

    if (viewBackground.startsWith("linear-gradient")) {
        val backgroundLinearColor =
            StyleConverter.instance.backgroundLinearColor(viewAttr?.background)
        if (this is Text) {
            // 不做处理，TextView的情况需要分开单独处理
        } else {
            if (backgroundLinearColor != null) {
                this.background = backgroundLinearColor.createDrawable()
            } else {
                this.background = null
            }
        }
    }else if(OTHelper.isNetSrc(viewBackground)){
        // TODO：处理网络图片背景

    } else if(OTHelper.isResSrc(viewBackground)){
        // TODO：处理本地资源图片背景

    } else{
        val backgroundColor = StyleConverter.instance.backgroundColor(viewAttr?.background)
        if (backgroundColor != null) {
            this.background = backgroundColor.createBackgroundColorDrawable()
        } else {
            this.background = null
        }
    }

    if (background is ColorGradientDrawable || background is LinearColorGradientDrawable) {
        (background as GradientDrawable).cornerRadii = viewAttr?.let {
            StyleConverter.instance.borderRadius(
                it
            )?.value
        }
    }
}

fun Text.setTextBackground(backgroundDrawable: OTLinearColor?) {
    if (backgroundDrawable != null) {
        this.setTextColor(Color.BLACK) // default Color is black
        this.paint.shader = backgroundDrawable.createShader(this)
    }
}

fun Text.setTextAlign(alignStr: String) {
    val textAlign = StyleConverter.instance.textAlign(alignStr)
    if (textAlign != null) {
        this.gravity = Gravity.CENTER_VERTICAL.or(textAlign)
    } else {
        this.gravity = Gravity.CENTER_VERTICAL.or(Gravity.LEFT)
    }
}

