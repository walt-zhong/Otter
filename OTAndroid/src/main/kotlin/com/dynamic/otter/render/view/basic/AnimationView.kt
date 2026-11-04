package com.dynamic.otter.render.view.basic

import android.content.Context
import android.util.AttributeSet
import com.airbnb.lottie.LottieAnimationView
import com.airbnb.lottie.LottieComposition
import com.airbnb.lottie.LottieCompositionFactory
import com.airbnb.lottie.LottieDrawable
import com.airbnb.lottie.LottieListener
import com.dynamic.otter.data.OTHelper
import com.dynamic.otter.utils.AssetsUtils
import com.dynamic.otter.render.view.attr.AnimationViewAttr
import com.dynamic.otter.render.view.basic.capability.IDataBindingCapability

class AnimationView : LottieAnimationView, IDataBindingCapability, Playable {
    private var url: String? = null
    private var autoPlay: Boolean = true
    private var aniRepeatCount: Int = LottieDrawable.INFINITE
    private var aniRepeatMode: Int = LottieDrawable.RESTART

    constructor(context: Context) : super(context)

    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs)

    constructor(context: Context, attrs: AttributeSet?, defStyle: Int) : super(
        context,
        attrs,
        defStyle
    )

    override fun setPlaying(playing: Boolean) {
        if (playing) {
            resumeAnimation()
        } else {
            pauseAnimation()
        }
    }

    override fun onBindData(data: Any?) {
        val attr = data as? AnimationViewAttr ?: return
        url = attr.animationSrc
        autoPlay = attr.autoPlay.equals("true", ignoreCase = true)
        aniRepeatCount = parseRepeatCount(attr.repeatCount)
        aniRepeatMode = parseRepeatMode(attr.repeatMode)
        if (autoPlay) {
            playAnimationFromBoundUrl()
        }
    }

    private fun playAnimationFromBoundUrl() {
        val source = url ?: return
        when {
            OTHelper.isNetSrc(source) && source.startsWith("https:") ->
                playNetAnimation(source, aniRepeatCount, aniRepeatMode)
            OTHelper.isAssetsSrc(source) -> {
                val assetPath = AssetsUtils.containedAssetPath(OTHelper.getAssetsSrc(source)) ?: return
                assetImageFolder(assetPath)?.let { imageAssetsFolder = it }
                playAssetsAnimation(assetPath, aniRepeatCount, aniRepeatMode)
            }
        }
    }

    private fun playNetAnimation(url: String, loopCount: Int, loopMode: Int) {
        val downloadTask = LottieCompositionFactory.fromUrl(context, url)
        val listener = object : LottieListener<LottieComposition> {
            override fun onResult(result: LottieComposition?) {
                downloadTask.removeListener(this)
                result?.let {
                    setComposition(it)
                    repeatCount = loopCount
                    repeatMode = loopMode
                    playAnimation()
                }
            }
        }
        downloadTask.addListener(listener)
    }

    private fun playAssetsAnimation(url: String, loopCount: Int, loopMode: Int) {
        setAnimation(appendJsonExtension(url))
        repeatCount = loopCount
        repeatMode = loopMode
        playAnimation()
    }

    private fun parseRepeatCount(raw: String?): Int {
        if (raw.equals("infinite", ignoreCase = true)) {
            return LottieDrawable.INFINITE
        }
        return if (raw != null && OTHelper.isNumeric(raw)) raw.toInt() else LottieDrawable.INFINITE
    }

    private fun parseRepeatMode(raw: String?): Int {
        return if (raw.equals("reverse", ignoreCase = true)) {
            LottieDrawable.REVERSE
        } else {
            LottieDrawable.RESTART
        }
    }

    private fun assetImageFolder(assetPath: String): String? {
        val dirIndex = assetPath.indexOf("/")
        if (dirIndex <= 0) {
            return null
        }
        val dir = assetPath.substring(0, dirIndex)
        return if (dir.isEmpty()) null else "$dir/images/"
    }

    private fun appendJsonExtension(value: String): String {
        return if (value.endsWith(".json")) value else "$value.json"
    }
}
