package com.dynamic.otter.render.view.drawable

import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorFilter
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.PorterDuff
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.RenderEffect
import android.graphics.RenderNode
import android.graphics.RuntimeShader
import android.graphics.Shader
import android.graphics.drawable.Drawable
import android.os.Build
import androidx.annotation.RequiresApi
import kotlin.math.max

/**
 * Android 上的液态玻璃。样式对齐 UIGlassEffect 的 regular / clear。
 * Android 13 及以上用圆角 SDF 做边缘折射和色散，这是 Kyant0、Haze、LiquidGlassView 的同一套透镜，
 * 而不是再铺一层厚白。更早的版本退回模糊加薄着色。子节点由 View 画在这层上面。
 */
internal class LiquidGlassDrawable : Drawable() {
    private val bitmapPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        isFilterBitmap = true
        colorFilter = ColorMatrixColorFilter(ColorMatrix().apply { setSaturation(1.12f) })
    }
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
    private val sheenPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeJoin = Paint.Join.ROUND
    }
    private val shape = Path()
    private val shapeRect = RectF()

    private var tint: Int = 0x38FFFFFF
    private var highlight: Float = 0.42f
    private var clear: Boolean = false
    private var interactive: Boolean = false
    private var pressed: Boolean = false
    private var radii = FloatArray(8)
    private var strokeColor: Int = Color.WHITE
    private var strokeWidth: Float = 1f
    private var solidStroke: Boolean = false
    private var refractionPx: Float = 0f
    private var dispersion: Float = 0f
    private var bevelPx: Float = 1f
    private var frostPx: Float = 0f
    private var padPx: Float = 0f
    private var roomLeft = 0f
    private var roomTop = 0f
    private var roomRight = 0f
    private var roomBottom = 0f
    private var fallback: Boolean = true
    private var useLens: Boolean = false
    private var lensBroken: Boolean = false
    private var lens: GlassLens? = null
    private var backdrop: Bitmap? = null
    private var sampleRadius: Float = 0f
    private var renderBlur: GlassBlurNode? = null
    private var soft: Bitmap? = null
    private var shaderWidth = -1
    private var shaderHeight = -1

    fun setAppearance(
        tint: Int,
        highlight: Float,
        clear: Boolean,
        interactive: Boolean,
        radii: FloatArray,
        strokeColor: Int,
        strokeWidth: Float,
        solidStroke: Boolean,
        refractionPx: Float,
        dispersion: Float
    ) {
        this.tint = tint
        this.highlight = highlight.coerceIn(0f, 1.2f)
        this.clear = clear
        this.interactive = interactive
        if (!interactive) {
            pressed = false
        }
        this.radii = if (radii.size == 8) radii.copyOf() else FloatArray(8)
        this.strokeColor = strokeColor
        this.strokeWidth = strokeWidth.coerceAtLeast(0f)
        this.solidStroke = solidStroke
        this.refractionPx = refractionPx.coerceAtLeast(0f)
        this.dispersion = dispersion.coerceIn(0f, 1f)
        shaderWidth = -1
        invalidateSelf()
    }

    fun setBackdrop(
        bitmap: Bitmap,
        blurPxOnSample: Float,
        padPx: Float,
        bevelPx: Float,
        frostPx: Float,
        roomLeft: Float,
        roomTop: Float,
        roomRight: Float,
        roomBottom: Float
    ) {
        backdrop = bitmap
        fallback = false
        sampleRadius = blurPxOnSample.coerceAtLeast(0f)
        this.padPx = padPx.coerceAtLeast(0f)
        this.bevelPx = bevelPx.coerceAtLeast(1f)
        this.frostPx = frostPx.coerceAtLeast(0f)
        this.roomLeft = roomLeft.coerceAtLeast(0f)
        this.roomTop = roomTop.coerceAtLeast(0f)
        this.roomRight = roomRight.coerceAtLeast(0f)
        this.roomBottom = roomBottom.coerceAtLeast(0f)
        soft?.takeIf { !it.isRecycled }?.recycle()
        soft = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !lensBroken) {
            // 透镜自己在边缘取样，位图保持锐利，模糊只发生在玻璃中心。
            renderBlur?.release()
            renderBlur = null
            useLens = true
            return
        }
        useLens = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && sampleRadius >= 0.5f) {
            val node = renderBlur ?: RenderEffectGlassBlur().also { renderBlur = it }
            node.record(bitmap, sampleRadius)
        } else {
            renderBlur?.release()
            renderBlur = null
            val radius = sampleRadius.toInt().coerceIn(0, 24)
            if (radius >= 1) {
                StackBlur.blur(bitmap, radius)
            }
        }
    }

    fun setFallback() {
        fallback = true
        useLens = false
        backdrop = null
    }

    fun release() {
        useLens = false
        renderBlur?.release()
        renderBlur = null
        lens?.release()
        lens = null
        backdrop = null
        soft?.takeIf { !it.isRecycled }?.recycle()
        soft = null
        fallback = true
    }

    override fun isStateful(): Boolean = interactive

    override fun onStateChange(state: IntArray): Boolean {
        if (!interactive) {
            return false
        }
        val next = state.contains(android.R.attr.state_pressed)
        if (next == pressed) {
            return false
        }
        pressed = next
        shaderWidth = -1
        return true
    }

    override fun draw(canvas: Canvas) {
        val area = bounds
        if (area.width() <= 0 || area.height() <= 0) {
            return
        }
        val canLens = useLens &&
            !lensBroken &&
            backdrop != null &&
            canvas.isHardwareAccelerated &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
        if (!canLens) {
            rebuildShaders(area.width(), area.height())
        }
        val checkpoint = canvas.save()
        clipShape(canvas, area)
        val lensDrawn = canLens && drawLens(canvas, area)
        if (!lensDrawn) {
            if (canLens) {
                rebuildShaders(area.width(), area.height())
            }
            drawBackdrop(canvas, area)
            canvas.drawRect(area, fillPaint)
            if (highlight > 0f) {
                canvas.drawRect(area, sheenPaint)
            }
        }
        if (strokeWidth > 0f && (solidStroke || !lensDrawn)) {
            drawStroke(canvas, area)
        }
        canvas.restoreToCount(checkpoint)
    }

    private fun drawBackdrop(canvas: Canvas, area: Rect) {
        val bitmap = backdrop
        if (bitmap == null || bitmap.isRecycled || fallback) {
            val shader = fillPaint.shader
            fillPaint.shader = null
            fillPaint.color = boosted(effectiveTint())
            canvas.drawRect(area, fillPaint)
            fillPaint.color = Color.WHITE
            fillPaint.shader = shader
            return
        }
        val node = renderBlur
        if (node != null && canvas.isHardwareAccelerated) {
            node.draw(canvas, bitmap, area)
            return
        }
        val painted = if (node != null) softwareCopy(bitmap) else bitmap
        canvas.drawBitmap(painted, null, area, bitmapPaint)
    }

    private fun softwareCopy(source: Bitmap): Bitmap {
        val existing = soft
        if (existing != null && !existing.isRecycled) {
            return existing
        }
        val copy = source.copy(Bitmap.Config.ARGB_8888, true)
        val radius = sampleRadius.toInt().coerceIn(1, 24)
        StackBlur.blur(copy, radius)
        soft = copy
        return copy
    }

    private fun drawStroke(canvas: Canvas, area: Rect) {
        val inset = strokeWidth / 2f
        shapeRect.set(area)
        shapeRect.inset(inset, inset)
        if (solidStroke) {
            strokePaint.shader = null
            strokePaint.color = strokeColor
        } else {
            strokePaint.color = Color.WHITE
            val top = if (clear) 0xFF else 0xE6
            val mid = if (clear) 0xA6 else 0x59
            val bottom = if (clear) 0x52 else 0x28
            strokePaint.shader = LinearGradient(
                shapeRect.left,
                shapeRect.top,
                shapeRect.left,
                shapeRect.bottom,
                intArrayOf(
                    withAlpha(top, Color.WHITE),
                    withAlpha(mid, Color.WHITE),
                    withAlpha(bottom, Color.WHITE)
                ),
                floatArrayOf(0f, 0.42f, 1f),
                Shader.TileMode.CLAMP
            )
        }
        strokePaint.strokeWidth = strokeWidth
        val radius = uniformRadius()
        shape.reset()
        if (radius != null) {
            val corner = (radius - inset).coerceAtLeast(0f)
            shape.addRoundRect(shapeRect, corner, corner, Path.Direction.CW)
        } else {
            val strokeRadii = FloatArray(8) { index ->
                (radii[index] - inset).coerceAtLeast(0f)
            }
            shape.addRoundRect(shapeRect, strokeRadii, Path.Direction.CW)
        }
        canvas.drawPath(shape, strokePaint)
    }

    private fun clipShape(canvas: Canvas, area: Rect) {
        val radius = uniformRadius() ?: -1f
        if (radius == 0f) {
            return
        }
        shape.reset()
        shapeRect.set(area)
        if (radius > 0f) {
            shape.addRoundRect(shapeRect, radius, radius, Path.Direction.CW)
        } else {
            shape.addRoundRect(shapeRect, radii, Path.Direction.CW)
        }
        canvas.clipPath(shape)
    }

    private fun rebuildShaders(width: Int, height: Int) {
        if (width == shaderWidth && height == shaderHeight) {
            return
        }
        shaderWidth = width
        shaderHeight = height
        val body = effectiveTint()
        val keep = if (clear) 0.35f else 0.55f
        val bottomAlpha = (Color.alpha(body) * keep).toInt().coerceIn(0, 255)
        fillPaint.color = Color.WHITE
        fillPaint.shader = LinearGradient(
            0f,
            0f,
            0f,
            height.toFloat(),
            intArrayOf(
                body,
                Color.argb(bottomAlpha, Color.red(body), Color.green(body), Color.blue(body))
            ),
            null,
            Shader.TileMode.CLAMP
        )
        val factor = (if (pressed) highlight * 1.35f else highlight).coerceAtMost(1.2f)
        val topBase = if (clear) 0x2E else 0x66
        val midBase = if (clear) 0x0C else 0x18
        val sheenHeight = if (clear) height * 0.22f else height * 0.4f
        sheenPaint.shader = LinearGradient(
            0f,
            0f,
            0f,
            sheenHeight.coerceAtLeast(1f),
            intArrayOf(
                withAlpha((topBase * factor).toInt(), Color.WHITE),
                withAlpha((midBase * factor).toInt(), Color.WHITE),
                Color.TRANSPARENT
            ),
            floatArrayOf(0f, 0.45f, 1f),
            Shader.TileMode.CLAMP
        )
    }

    private fun effectiveTint(): Int {
        if (!pressed) {
            return tint
        }
        return withAlpha((Color.alpha(tint) * 1.28f).toInt(), tint)
    }

    private fun uniformRadius(): Float? {
        if (radii.size != 8) {
            return 0f
        }
        val first = radii[0]
        return if (radii.all { it == first }) first else null
    }

    override fun setAlpha(alpha: Int) {
        bitmapPaint.alpha = alpha
        fillPaint.alpha = alpha
        sheenPaint.alpha = alpha
        strokePaint.alpha = alpha
    }

    override fun setColorFilter(colorFilter: ColorFilter?) {
        fillPaint.colorFilter = colorFilter
    }

    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = PixelFormat.TRANSLUCENT

    private fun withAlpha(alpha: Int, color: Int): Int {
        return Color.argb(
            alpha.coerceIn(0, 255),
            Color.red(color),
            Color.green(color),
            Color.blue(color)
        )
    }

    private fun drawLens(canvas: Canvas, area: Rect): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return false
        }
        val bitmap = backdrop ?: return false
        if (bitmap.isRecycled) {
            return false
        }
        return try {
            drawLensTiramisu(canvas, area, bitmap)
        } catch (error: Throwable) {
            android.util.Log.w("OtterGlass", "lens failed", error)
            lensBroken = true
            useLens = false
            false
        }
    }

    @RequiresApi(Build.VERSION_CODES.TIRAMISU)
    private fun drawLensTiramisu(canvas: Canvas, area: Rect, bitmap: Bitmap): Boolean {
        val current = (lens as? AgslGlassLens) ?: AgslGlassLens().also { lens = it }
        val corner = uniformRadius() ?: radii.maxOrNull() ?: 0f
        val boost = if (pressed) 1.28f else 1f
        current.draw(
            canvas,
            bitmap,
            area,
            corner,
            refractionPx * boost,
            dispersion,
            effectiveTint(),
            bevelPx,
            frostPx,
            padPx,
            roomLeft,
            roomTop,
            roomRight,
            roomBottom
        )
        return true
    }

    private fun boosted(color: Int): Int {
        return Color.argb(
            max(Color.alpha(color), 0x99),
            Color.red(color),
            Color.green(color),
            Color.blue(color)
        )
    }
}

internal interface GlassBlurNode {
    fun record(bitmap: Bitmap, radius: Float)
    fun draw(canvas: Canvas, bitmap: Bitmap, area: Rect)
    fun release()
}

@RequiresApi(Build.VERSION_CODES.S)
internal class RenderEffectGlassBlur : GlassBlurNode {
    private val node = RenderNode("OtterLiquidGlass")

    override fun record(bitmap: Bitmap, radius: Float) {
        node.setPosition(0, 0, bitmap.width, bitmap.height)
        val recording = node.beginRecording()
        try {
            recording.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)
            recording.drawBitmap(bitmap, 0f, 0f, null)
        } finally {
            node.endRecording()
        }
        node.setRenderEffect(RenderEffect.createBlurEffect(radius, radius, Shader.TileMode.MIRROR))
    }

    override fun draw(canvas: Canvas, bitmap: Bitmap, area: Rect) {
        canvas.save()
        canvas.translate(area.left.toFloat(), area.top.toFloat())
        canvas.scale(area.width().toFloat() / bitmap.width, area.height().toFloat() / bitmap.height)
        canvas.drawRenderNode(node)
        canvas.restore()
    }

    override fun release() {
        node.discardDisplayList()
    }
}

internal interface GlassLens {
    fun draw(
        canvas: Canvas,
        bitmap: Bitmap,
        area: Rect,
        radius: Float,
        refraction: Float,
        dispersion: Float,
        tint: Int,
        bevel: Float,
        frost: Float,
        pad: Float,
        roomLeft: Float,
        roomTop: Float,
        roomRight: Float,
        roomBottom: Float
    )

    fun release()
}

@RequiresApi(Build.VERSION_CODES.TIRAMISU)
internal class AgslGlassLens : GlassLens {
    private val runtime = RuntimeShader(SOURCE)
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private var shader: BitmapShader? = null
    private var attached: Bitmap? = null

    override fun draw(
        canvas: Canvas,
        bitmap: Bitmap,
        area: Rect,
        radius: Float,
        refraction: Float,
        dispersion: Float,
        tint: Int,
        bevel: Float,
        frost: Float,
        pad: Float,
        roomLeft: Float,
        roomTop: Float,
        roomRight: Float,
        roomBottom: Float
    ) {
        val bitmapShader = if (attached === bitmap) {
            shader!!
        } else {
            BitmapShader(bitmap, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).also {
                shader = it
                attached = bitmap
                runtime.setInputShader("content", it)
            }
        }
        bitmapShader.setLocalMatrix(null)
        runtime.setFloatUniform("origin", area.left.toFloat(), area.top.toFloat())
        runtime.setFloatUniform("size", area.width().toFloat(), area.height().toFloat())
        runtime.setFloatUniform("radius", radius)
        runtime.setFloatUniform("refraction", refraction)
        runtime.setFloatUniform("dispersion", dispersion)
        runtime.setFloatUniform("bevel", bevel)
        runtime.setFloatUniform("frost", frost)
        runtime.setFloatUniform("room", roomLeft, roomTop, roomRight, roomBottom)
        val extentW = area.width().toFloat() + pad * 2f
        val extentH = area.height().toFloat() + pad * 2f
        runtime.setFloatUniform(
            "mapScale",
            bitmap.width / extentW.coerceAtLeast(1f),
            bitmap.height / extentH.coerceAtLeast(1f)
        )
        runtime.setFloatUniform("mapPad", pad, pad)
        runtime.setFloatUniform(
            "tint",
            Color.red(tint) / 255f,
            Color.green(tint) / 255f,
            Color.blue(tint) / 255f,
            Color.alpha(tint) / 255f
        )
        paint.shader = runtime
        canvas.drawRect(area, paint)
    }

    override fun release() {
        shader = null
        attached = null
        paint.shader = null
    }

    companion object {
        private const val SOURCE = """
            uniform shader content;
            uniform float2 origin;
            uniform float2 size;
            uniform float radius;
            uniform float refraction;
            uniform float dispersion;
            uniform float bevel;
            uniform float frost;
            uniform float4 room;
            uniform float2 mapScale;
            uniform float2 mapPad;
            uniform float4 tint;

            float roundRect(float2 p, float2 b, float r) {
                float2 q = abs(p) - b + float2(r);
                return length(max(q, float2(0.0))) + min(max(q.x, q.y), 0.0) - r;
            }

            float2 glassUv(float2 p) {
                float2 lo = origin - float2(room.x, room.y);
                float2 hi = origin + size + float2(room.z, room.w);
                p = clamp(p, lo, hi);
                return (p - origin + mapPad) * mapScale;
            }

            half4 main(float2 coord) {
                float2 halfSize = size * 0.5;
                float2 center = origin + halfSize;
                float2 p = coord - center;
                float r = min(radius, min(halfSize.x, halfSize.y));
                float d = roundRect(p, halfSize, r);
                float dx = roundRect(p + float2(1.0, 0.0), halfSize, r)
                         - roundRect(p - float2(1.0, 0.0), halfSize, r);
                float dy = roundRect(p + float2(0.0, 1.0), halfSize, r)
                         - roundRect(p - float2(0.0, 1.0), halfSize, r);
                float2 n = float2(dx, dy);
                float nLen = length(n);
                n = nLen > 0.001 ? n / nLen : float2(0.0, -1.0);
                float distIn = max(-d, 0.0);
                float t = clamp(distIn / max(bevel, 1.0), 0.0, 1.0);
                float rim = pow(1.0 - t, 1.5);
                float2 bent = coord + n * refraction * rim;
                float spread = refraction * dispersion * rim;
                half4 color = content.eval(glassUv(bent));
                color.r = content.eval(glassUv(bent + n * spread)).r;
                color.b = content.eval(glassUv(bent - n * spread)).b;
                float blur = frost * t;
                if (blur > 0.8) {
                    half4 acc = color;
                    acc += content.eval(glassUv(bent + float2(blur, 0.0)));
                    acc += content.eval(glassUv(bent + float2(-blur, 0.0)));
                    acc += content.eval(glassUv(bent + float2(0.0, blur)));
                    acc += content.eval(glassUv(bent + float2(0.0, -blur)));
                    color = acc * 0.2;
                }
                float sky = clamp(-n.y, 0.0, 1.0);
                float ground = clamp(n.y, 0.0, 1.0);
                float hair = smoothstep(3.2, 0.4, distIn) * sky;
                color.rgb = mix(color.rgb, half3(1.0), hair * 0.55);
                float sole = smoothstep(7.0, 0.6, distIn) * ground;
                color.rgb *= 1.0 - sole * 0.16;
                color.rgb = mix(color.rgb, half3(tint.r, tint.g, tint.b), tint.a);
                color.a = 1.0;
                return color;
            }
        """
    }
}
