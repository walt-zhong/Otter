package com.dynamic.otter.render.view.drawable

import android.graphics.Bitmap
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

internal object StackBlur {
    fun blur(bitmap: Bitmap, radius: Int) {
        if (radius < 1) {
            return
        }
        val w = bitmap.width
        val h = bitmap.height
        if (w < 2 || h < 2) {
            return
        }
        val pix = IntArray(w * h)
        bitmap.getPixels(pix, 0, w, 0, 0, w, h)
        val wm = w - 1
        val hm = h - 1
        val div = radius + radius + 1
        var divsum = (div + 1) shr 1
        divsum *= divsum
        val dv = IntArray(256 * divsum) { index -> index / divsum }
        val r = IntArray(w * h)
        val g = IntArray(w * h)
        val b = IntArray(w * h)
        val vmin = IntArray(max(w, h))
        val stack = Array(div) { IntArray(3) }
        val r1 = radius + 1

        var yw = 0
        var yi = 0
        for (y in 0 until h) {
            var rinsum = 0
            var ginsum = 0
            var binsum = 0
            var routsum = 0
            var goutsum = 0
            var boutsum = 0
            var rsum = 0
            var gsum = 0
            var bsum = 0
            for (i in -radius..radius) {
                val p = pix[yi + min(wm, max(i, 0))]
                val sir = stack[i + radius]
                sir[0] = (p and 0xff0000) shr 16
                sir[1] = (p and 0x00ff00) shr 8
                sir[2] = p and 0x0000ff
                val rbs = r1 - abs(i)
                rsum += sir[0] * rbs
                gsum += sir[1] * rbs
                bsum += sir[2] * rbs
                if (i > 0) {
                    rinsum += sir[0]
                    ginsum += sir[1]
                    binsum += sir[2]
                } else {
                    routsum += sir[0]
                    goutsum += sir[1]
                    boutsum += sir[2]
                }
            }
            var stackPointer = radius
            for (x in 0 until w) {
                r[yi] = dv[rsum]
                g[yi] = dv[gsum]
                b[yi] = dv[bsum]
                rsum -= routsum
                gsum -= goutsum
                bsum -= boutsum
                val stackStart = stackPointer - radius + div
                val sir = stack[stackStart % div]
                routsum -= sir[0]
                goutsum -= sir[1]
                boutsum -= sir[2]
                if (y == 0) {
                    vmin[x] = min(x + radius + 1, wm)
                }
                val p = pix[yw + vmin[x]]
                sir[0] = (p and 0xff0000) shr 16
                sir[1] = (p and 0x00ff00) shr 8
                sir[2] = p and 0x0000ff
                rinsum += sir[0]
                ginsum += sir[1]
                binsum += sir[2]
                rsum += rinsum
                gsum += ginsum
                bsum += binsum
                stackPointer = (stackPointer + 1) % div
                val next = stack[stackPointer]
                routsum += next[0]
                goutsum += next[1]
                boutsum += next[2]
                rinsum -= next[0]
                ginsum -= next[1]
                binsum -= next[2]
                yi++
            }
            yw += w
        }

        for (x in 0 until w) {
            var rinsum = 0
            var ginsum = 0
            var binsum = 0
            var routsum = 0
            var goutsum = 0
            var boutsum = 0
            var rsum = 0
            var gsum = 0
            var bsum = 0
            var yp = -radius * w
            for (i in -radius..radius) {
                val yiRow = max(0, yp) + x
                val sir = stack[i + radius]
                sir[0] = r[yiRow]
                sir[1] = g[yiRow]
                sir[2] = b[yiRow]
                val rbs = r1 - abs(i)
                rsum += r[yiRow] * rbs
                gsum += g[yiRow] * rbs
                bsum += b[yiRow] * rbs
                if (i > 0) {
                    rinsum += sir[0]
                    ginsum += sir[1]
                    binsum += sir[2]
                } else {
                    routsum += sir[0]
                    goutsum += sir[1]
                    boutsum += sir[2]
                }
                if (i < hm) {
                    yp += w
                }
            }
            var yiCol = x
            var stackPointer = radius
            for (y in 0 until h) {
                pix[yiCol] = (0xff shl 24) or (dv[rsum] shl 16) or (dv[gsum] shl 8) or dv[bsum]
                rsum -= routsum
                gsum -= goutsum
                bsum -= boutsum
                val stackStart = stackPointer - radius + div
                val sir = stack[stackStart % div]
                routsum -= sir[0]
                goutsum -= sir[1]
                boutsum -= sir[2]
                if (x == 0) {
                    vmin[y] = min(y + r1, hm) * w
                }
                val p = x + vmin[y]
                sir[0] = r[p]
                sir[1] = g[p]
                sir[2] = b[p]
                rinsum += sir[0]
                ginsum += sir[1]
                binsum += sir[2]
                rsum += rinsum
                gsum += ginsum
                bsum += binsum
                stackPointer = (stackPointer + 1) % div
                val next = stack[stackPointer]
                routsum += next[0]
                goutsum += next[1]
                boutsum += next[2]
                rinsum -= next[0]
                ginsum -= next[1]
                binsum -= next[2]
                yiCol += w
            }
        }
        bitmap.setPixels(pix, 0, w, 0, 0, w, h)
    }
}
