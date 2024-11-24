package com.dynamic.otter.render.view.basic

import android.content.Context
import android.content.res.Resources
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.util.AttributeSet
import android.widget.ImageView
import androidx.annotation.Keep
import androidx.appcompat.widget.AppCompatImageView
import androidx.core.content.res.ResourcesCompat
import com.alibaba.fastjson.JSONObject
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
    ICornerRoundConfigCapability,IStyleBindingCapability {
    private val roundBorderWorker by lazy {
        ImageRoundBorderWorker()
    }

    constructor(context: Context) : super(context)
    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs)
    constructor(context: Context, attrs: AttributeSet?, defStyle: Int) : super(
        context,
        attrs,
        defStyle
    )

    override fun onBindData(data: Any?) {
        scaleType = ScaleType.CENTER_CROP
        // 若只是传了一个String,说明只有一个Src,直接加载就行
        when (data) {
            is String -> {
                // 如果是网络图片，使用glide加载
                if (OTHelper.isNetSrc(data)) {
                    Glide.with(context).load(data).into(this)
                }else if(OTHelper.isResSrc(data)){
                    val finaLocalUrl = getResSrc(data)
                    bindRes(finaLocalUrl)
                }
                // 如果传递过来的是一个json对象，说明有很多的数据需要绑定，比如无障碍信息，placeholder等
            }

            is JSONObject -> {
                // TODO 需要添加无障碍信息，placeholder等
            }
        }
    }

    override fun onBindStyle(attr: ViewAttr, attrData:Any?) {
        if (attr is ImageAttr) {
            updateByAttr(attr)
        }
    }

    private fun updateByAttr(imageAttr: ImageAttr) {
    }


    private fun bindRes(resUri: String) {
        try {
            val res: Int = getResIdByUrl(this, resUri)
            val drawable = getDrawableByResId(this, res)
            this.setImageDrawable(drawable)
        } catch (e: Exception) {
            e.printStackTrace()
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

    override fun onClear() {
        super.onClear()
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