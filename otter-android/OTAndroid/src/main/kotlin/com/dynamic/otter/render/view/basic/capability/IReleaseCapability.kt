package com.dynamic.otter.render.view.basic.capability

/**
 * 实现这个接口的View表示需要可释放的能力，比如图片，文字等
 */
interface IReleaseCapability {
    fun release()
}