package com.dynamic.otter.render.view

import android.graphics.Color
import android.graphics.Outline
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.view.ViewOutlineProvider
import android.widget.TextView
import androidx.core.content.res.ResourcesCompat
import com.dynamic.otter.data.OTHelper
import com.dynamic.otter.render.view.attr.ViewAttr
import com.dynamic.otter.render.view.basic.Column
import com.dynamic.otter.render.view.basic.Text
import com.dynamic.otter.render.view.basic.capability.ICornerRoundConfigCapability
import com.dynamic.otter.render.view.drawable.ColorGradientDrawable
import com.dynamic.otter.render.view.drawable.CoverBitmapDrawable
import com.dynamic.otter.render.view.drawable.PanningBitmapDrawable
import com.dynamic.otter.render.view.drawable.LinearColorGradientDrawable
import com.dynamic.otter.render.view.drawable.LiquidGlassController
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
    if (viewAttr?.glassStyle != null) {
        LiquidGlassController.attach(this, viewAttr)
        return
    }
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
    if (viewAttr?.glassStyle != null) {
        LiquidGlassController.attach(this, viewAttr)
        return
    }
    LiquidGlassController.release(this)
    val viewBackground = viewAttr?.background.orEmpty()
    if (viewBackground.startsWith("linear-gradient")) {
        if (this !is Text) {
            background = StyleConverter.backgroundLinearColor(viewBackground)?.createDrawable()
        }
    } else if (OTHelper.isResSrc(viewBackground)) {
        val name = OTHelper.getResSrc(viewBackground)
        background = if (this is Column) {
            panBackground(name) ?: coverBackground(this, name)
        } else {
            coverBackground(this, name)
        }
    } else if (!OTHelper.isNetSrc(viewBackground)) {
        background = StyleConverter.backgroundColor(viewAttr?.background)?.createBackgroundColorDrawable()
    }

    if (background is ColorGradientDrawable || background is LinearColorGradientDrawable) {
        (background as GradientDrawable).cornerRadii = viewAttr?.let { StyleConverter.borderRadius(it)?.value }
    }
}

private fun View.panBackground(name: String): Drawable? {
    val drawable = loadBackground(this, name) ?: return null
    val bitmap = (drawable as? BitmapDrawable)?.bitmap ?: return drawable
    return PanningBitmapDrawable(bitmap)
}

private fun coverBackground(view: View, name: String): Drawable? {
    val drawable = loadBackground(view, name) ?: return null
    val bitmap = (drawable as? BitmapDrawable)?.bitmap ?: return drawable
    return CoverBitmapDrawable(bitmap)
}

private fun loadBackground(view: View, name: String): Drawable? {
    val id = view.resources.getIdentifier(name, "drawable", view.context.packageName)
    if (id == 0) {
        return null
    }
    return ResourcesCompat.getDrawable(view.resources, id, view.context.theme)
}

fun Text.setTextBackground(backgroundDrawable: OTLinearColor?) {
    if (backgroundDrawable != null) {
        this.setTextColor(Color.BLACK) // default Color is black
        this.paint.shader = backgroundDrawable.createShader(this)
    }
}

fun TextView.setTextAlign(alignStr: String) {
    val textAlign = StyleConverter.textAlign(alignStr)
    if (textAlign != null) {
        this.gravity = Gravity.CENTER_VERTICAL.or(textAlign)
    } else {
        this.gravity = Gravity.CENTER_VERTICAL.or(Gravity.LEFT)
    }
}

