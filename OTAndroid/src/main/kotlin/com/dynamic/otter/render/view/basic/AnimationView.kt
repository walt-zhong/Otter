package com.dynamic.otter.render.view.basic

import android.content.Context
import android.util.AttributeSet
import com.airbnb.lottie.LottieAnimationView
import com.airbnb.lottie.LottieComposition
import com.airbnb.lottie.LottieCompositionFactory
import com.airbnb.lottie.LottieDrawable
import com.airbnb.lottie.LottieListener
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.data.OTHelper
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.view.basic.capability.IDataBindingCapability

class AnimationView : LottieAnimationView, IDataBindingCapability {
    constructor(context: Context) : super(context) {
        initView()
    }

    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs) {
        initView()
    }

    constructor(context: Context, attrs: AttributeSet?, defStyle: Int) : super(
        context,
        attrs,
        defStyle
    )

    private fun initView() {
    }

    private fun playSDNetAnimation(
        url: String,
        loopCount: Int = LottieDrawable.INFINITE,
        loopMode: Int = LottieDrawable.RESTART
    ) {
        val downloadTask = LottieCompositionFactory
            .fromUrl(
                context,
                url
            )

        downloadTask.addListener(object : LottieListener<LottieComposition> {
            override fun onResult(result: LottieComposition?) {
                downloadTask.removeListener(this)
                result?.let {
                    setComposition(it)
                    repeatCount = loopCount
                    repeatMode = loopMode
                    playAnimation()
                }
            }
        })
    }

    private fun playSDAssetsAnimation(
        url: String,
        loopCount: Int = LottieDrawable.INFINITE,
        loopMode: Int = LottieDrawable.RESTART
    ) {
        setAnimation(localAppendJsonExt(url))
        repeatCount = loopCount
        repeatMode = loopMode
        playAnimation()
    }

    private var url: String? = null
    private var autoPlay: Boolean = true
    private var aniRepeatCount: Int = LottieDrawable.INFINITE
    private var aniRepeatMode: Int = LottieDrawable.RESTART

    override fun onBindData(data: Any?) {
        if (data is JSONObject) {
            url = data[TemplateKey.ATTR_ANIMATION_SRC].toString()

            autoPlay = "true".equals(
                data[TemplateKey.ATTR_ANI_AUTO_PLAY].toString(), true
            )

            aniRepeatCount =
                if ("infinite".equals(data[TemplateKey.ATTR_ANI_REPEAT_COUNT].toString(), true)) {
                    LottieDrawable.INFINITE
                } else {
                    if (OTHelper.isNumeric(data[TemplateKey.ATTR_ANI_REPEAT_COUNT].toString())) {
                        data[TemplateKey.ATTR_ANI_REPEAT_COUNT].toString().toInt()
                    } else {
                        LottieDrawable.INFINITE
                    }
                }

            aniRepeatMode = data[TemplateKey.ATTR_ANI_REPEAT_MODE].toString().let {
                if ("restart".equals(it, true)) {
                    LottieDrawable.RESTART
                } else if ("reverse".equals(it, true)) {
                    LottieDrawable.REVERSE
                } else {
                    LottieDrawable.RESTART
                }
            }
            if (autoPlay) {
                playSdAnimation()
            }
        }
    }

    private fun playSdAnimation() {
        url?.let {
            if (OTHelper.isNetSrc(it)) {
                playSDNetAnimation(
                    it,
                    aniRepeatCount,
                    aniRepeatCount,
                )
            }

            if (OTHelper.isAssetsSrc(it)) {
                initLottieLocalResourceDir(it, this)
                playSDAssetsAnimation(
                    OTHelper.getAssetsSrc(it),
                    aniRepeatCount,
                    aniRepeatMode
                )
            }
        }
    }

    private fun initLottieLocalResourceDir(value: String, lottieView: LottieAnimationView) {
        val dirIndex = value.indexOf("/")
        if (dirIndex > 0) {
            val dir = value.substring(0, dirIndex)
            if (dir.isNotEmpty()) {
                lottieView.imageAssetsFolder = "$dir/images/"
            }
        }
    }

    private fun localAppendJsonExt(value: String?): String? {
        if (value != null && !value.endsWith(".json")) {
            return "$value.json"
        }
        return value
    }
}