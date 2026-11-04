package com.dynamic.otter.render.view.basic

import android.content.Context
import android.content.res.Resources
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.util.AttributeSet
import android.widget.ImageView
import androidx.annotation.Keep
import androidx.appcompat.widget.AppCompatImageView
import androidx.core.content.res.ResourcesCompat
import com.bumptech.glide.Glide
import com.dynamic.otter.data.OTHelper
import com.dynamic.otter.data.OTHelper.getResSrc
import com.dynamic.otter.render.view.attr.ImageAttr
import com.dynamic.otter.render.view.attr.ViewAttr
import com.dynamic.otter.render.view.basic.capability.ICornerRoundConfigCapability
import com.dynamic.otter.render.view.basic.capability.IDataBindingCapability
import com.dynamic.otter.render.view.basic.capability.IReleaseCapability
import com.dynamic.otter.render.view.basic.capability.IStyleBindingCapability
import com.dynamic.otter.render.view.worker.ImageRoundBorderWorker

@Keep
class Image : AppCompatImageView, IDataBindingCapability, IReleaseCapability,
    ICornerRoundConfigCapability, IStyleBindingCapability {
    private val roundBorderWorker by lazy {
        ImageRoundBorderWorker()
    }
    private var imageFit = "cover"
    private var placeholderColor: String? = null

    constructor(context: Context) : super(context)
    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs)
    constructor(context: Context, attrs: AttributeSet?, defStyle: Int) : super(
        context,
        attrs,
        defStyle
    )

    override fun onBindStyle(attr: ViewAttr, attrData: Any?) {
        val imageAttr = attr as? ImageAttr ?: return
        imageFit = imageAttr.fit
        placeholderColor = imageAttr.placeholder
    }

    override fun onBindData(data: Any?) {
        when (data) {
            is ImageAttr -> {
                imageFit = data.fit
                placeholderColor = data.placeholder
                bindSrc(data.src)
            }
            is String -> bindSrc(data)
        }
    }

    private fun bindSrc(src: String) {
        scaleType = scaleTypeFor(imageFit)
        val placeholder = placeholderDrawable()
        when {
            src.isBlank() -> showPlaceholder(placeholder)
            OTHelper.isNetSrc(src) -> {
                if (!src.startsWith("https:")) {
                    showPlaceholder(placeholder)
                } else {
                    loadModel(src, placeholder)
                }
            }
            OTHelper.isContentSrc(src) && src.startsWith("content://") ->
                loadModel(Uri.parse(src), placeholder)
            OTHelper.isResSrc(src) -> bindRes(getResSrc(src), placeholder)
            else -> showPlaceholder(placeholder)
        }
    }

    private fun scaleTypeFor(fit: String): ScaleType {
        return when (fit) {
            "contain" -> ScaleType.FIT_CENTER
            "fill" -> ScaleType.FIT_XY
            else -> ScaleType.CENTER_CROP
        }
    }

    private fun loadModel(model: Any, placeholder: ColorDrawable?) {
        try {
            val request = Glide.with(context).load(model)
            if (placeholder != null) {
                request.placeholder(ColorDrawable(placeholder.color))
                    .error(ColorDrawable(placeholder.color))
                    .into(this)
            } else {
                request.into(this)
            }
        } catch (e: Exception) {
            e.printStackTrace()
            showPlaceholder(placeholder)
        }
    }

    private fun showPlaceholder(placeholder: ColorDrawable?) {
        cancelRequest()
        setImageDrawable(placeholder)
    }

    private fun cancelRequest() {
        try {
            Glide.with(context).clear(this)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun placeholderDrawable(): ColorDrawable? {
        val color = parsePlaceholderColor(placeholderColor) ?: return null
        return ColorDrawable(color)
    }

    private fun parsePlaceholderColor(raw: String?): Int? {
        val color = raw?.trim().orEmpty()
        val hex = when (color.length) {
            4 -> {
                if (color[0] != '#') {
                    return null
                }
                val r = color[1]
                val g = color[2]
                val b = color[3]
                "#$r$r$g$g$b$b"
            }
            7, 9 -> if (color[0] == '#') color else return null
            else -> return null
        }
        return try {
            Color.parseColor(hex)
        } catch (ignored: IllegalArgumentException) {
            null
        }
    }

    private fun bindRes(resUri: String, placeholder: ColorDrawable?) {
        if (resUri.contains('/') || resUri.contains('\\') || resUri.contains("..")) {
            showPlaceholder(placeholder)
            return
        }
        cancelRequest()
        try {
            val res: Int = getResIdByUrl(this, resUri)
            val drawable = if (res != 0) getDrawableByResId(this, res) else null
            if (drawable != null) {
                setImageDrawable(drawable)
            } else if (placeholder != null) {
                setImageDrawable(placeholder)
            }
        } catch (e: Exception) {
            e.printStackTrace()
            if (placeholder != null) {
                setImageDrawable(placeholder)
            }
        }
    }

    private fun getResIdByUrl(imageView: ImageView, url: String): Int {
        try {
            // drawable resource
            imageView.resources.getIdentifier(url, "drawable", imageView.context.packageName)
                .takeIf { it != 0 }?.let {
                    return it
                }

            // mipmap resource
            imageView.resources.getIdentifier(url, "mipmap", imageView.context.packageName)
                .takeIf { it != 0 }?.let {
                    return it
                }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return 0
    }

    override fun release() {
        setImageDrawable(null)
    }

    private fun getDrawableByResId(imageView: ImageView, resId: Int): Drawable? {
        val theme: Resources.Theme = imageView.context.theme
        return ResourcesCompat.getDrawable(imageView.resources, resId, theme)
    }

    override fun draw(canvas: Canvas) {
        val width = measuredWidth.toFloat()
        val height = measuredHeight.toFloat()
        if (roundBorderWorker.isNeedRound(canvas, width, height)) {
            roundBorderWorker.draw(canvas, width, height) {
                super.draw(canvas)
            }
        } else {
            super.draw(canvas)
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val width = measuredWidth.toFloat()
        val height = measuredHeight.toFloat()
        if (roundBorderWorker.isNeedRound(canvas, width, height)) {
            roundBorderWorker.onDraw(canvas, width, height)
        }
    }

    override fun configureViewRoundCorner(radius: FloatArray) {
        roundBorderWorker.setRoundCornerRadius(radius)
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
        // TODO:这里实现的边框在ImageView上展示的时候据边缘会有几像素的距离，不是很贴合，需要优化
        roundBorderWorker.setRoundCornerBorder(borderColor, borderWidth, radius)
    }
}