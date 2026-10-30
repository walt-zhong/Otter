package com.dynamic.otter.utils

/**
 * 把设计稿宽度换算成当前窗口的缩放比。
 *
 * 设计基准是 375dp。普通手机按窗口宽度等比缩放；过窄的窗口不再继续缩小，
 * 避免字和点击区域小到不能用。平板和折叠屏内屏停在大屏手机的比例，
 * 多出来的宽度交给 fill 去撑开，而不是把每个控件继续放大。
 */
object ScreenAdapt {
    const val DESIGN_WIDTH_DP = 375f

    private const val MIN_SCALE = 0.88f
    private const val MAX_REFERENCE_DP = 480f

    fun scaleFor(windowWidthDp: Float, designWidthDp: Float = DESIGN_WIDTH_DP): Float {
        if (windowWidthDp <= 0f || designWidthDp <= 0f) {
            return 1f
        }
        val basis = windowWidthDp.coerceAtMost(MAX_REFERENCE_DP)
        return (basis / designWidthDp).coerceAtLeast(MIN_SCALE)
    }
}
