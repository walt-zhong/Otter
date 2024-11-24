package com.dynamic.otter.utils

import android.app.Activity
import android.content.Context
import android.content.res.Resources
import android.os.Build
import android.util.DisplayMetrics
import android.view.WindowManager
import com.dynamic.otter.OTEngine

/**
 * @suppress
 */
object ScreenUtils {

    private fun Float.convertPixelsToDp(): Float {
        return this / (Resources.getSystem().displayMetrics.densityDpi.toFloat() / DisplayMetrics.DENSITY_DEFAULT)
    }

    internal var isDebug: Boolean = false
    internal var screenWidth = 0F
    internal var screenHeight = 0F

    private val dm = DisplayMetrics()

    fun getScreenWidthPx(context: Context): Float {
        initScreen(context)
        return screenWidth
    }

    fun getScreenHeightPx(context: Context): Float {
        initScreen(context)
        return screenHeight
    }

    fun getScreenHeightDP(context: Context): Float {
        initScreen(context)
        return screenHeight.convertPixelsToDp()
    }

    fun getScreenWidthDP(context: Context): Float {
        initScreen(context)
        return screenWidth.convertPixelsToDp()
    }

    /**
     * 如果是未初始化过，或者是响应式状态下，需要重新初始化屏幕宽高值
     *
     * 1. 先从DecorView中获取
     * 2. 从多屏幕中获取
     * 3. 从ActivityWindow中获取
     * 4. 从Application中获取
     */
    private fun initScreen(context: Context) {
        if (isDebug) {
            return
        }
        if (context is Activity) {
            // DecorView 获取
            screenWidth = context.window.decorView.measuredWidth.toFloat()
            screenHeight = context.window.decorView.measuredHeight.toFloat()
            if (screenWidth != 0F && screenHeight != 0F) {
                return
            }

            // Multi Window 获取
            if (Build.VERSION.SDK_INT >= 24 && context.isInMultiWindowMode) {
                screenWidth =
                    Math.round((context.resources.configuration.screenWidthDp.toFloat() * context.resources.displayMetrics.density).toDouble() + 0.5)
                        .toFloat()
                screenHeight =
                    Math.round((context.resources.configuration.screenHeightDp.toFloat() * context.resources.displayMetrics.density).toDouble() + 0.5)
                        .toFloat()
                if (screenWidth != 0F && screenHeight != 0F) {
                    return
                }
            }

            // Activity Window 获取
            context.windowManager.defaultDisplay.getMetrics(dm)
            screenWidth = dm.widthPixels.toFloat()
            screenHeight = dm.heightPixels.toFloat()
        } else {
            // Application Window 获取
            val applicationContext = OTEngine.instance.context
            val windowManager =
                applicationContext.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
            if (windowManager != null) {
                windowManager.defaultDisplay?.getMetrics(dm)
                screenWidth = dm.widthPixels.toFloat()
                screenHeight = dm.heightPixels.toFloat()
            }
        }
    }

    fun dpAdapt(context: Context,dp:Float):Int{
        return dpAdapt(context,dp,360f)
    }

    private fun dpAdapt(
        context: Context,
        dp: Float,
        widthDpBase: Float
    ): Int {
        val dm = context.resources.displayMetrics
        val heightPixels = dm.heightPixels
        val widthPixels = dm.widthPixels
        val density = dm.density
        val heightDp = heightPixels / density
        val widthDp = widthPixels / density

        val w = widthDp.coerceAtMost(heightDp)
        return (dp * w / widthDpBase * density + 0.5).toInt()
    }

}