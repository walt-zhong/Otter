package com.dynamic.otter.render.view.drawable

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Outline
import android.graphics.Path
import android.graphics.RectF
import android.os.Build
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.view.ViewTreeObserver
import androidx.core.widget.NestedScrollView
import com.dynamic.otter.render.view.attr.ViewAttr
import com.dynamic.otter.render.view.basic.OTAbsoluteLayout
import com.dynamic.otter.template.OTSize
import com.dynamic.otter.template.StyleConverter
import com.dynamic.outter.R
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * 采样方式和 Kuikly 的 KRBlurView 一样：PreDraw 时先把盖在上面的兄弟藏起来，
 * 再把根视图画进一块缩小的位图。regular / clear 只决定模糊强度、薄厚和投影，
 * 作者不写 blur、高光、阴影。
 */
internal class LiquidGlassController private constructor(
    private val host: View
) : ViewTreeObserver.OnPreDrawListener, View.OnAttachStateChangeListener {
    val drawable = LiquidGlassDrawable()

    private var blurPx = 0f
    private var padPx = 0f
    private var bevelPx = 1f
    private var frostPx = 0f
    private var clearStyle = false
    private var buffer: Bitmap? = null
    private var observer: ViewTreeObserver? = null
    private var capturing = false
    private var captures = 0
    private var lastLeft = Int.MIN_VALUE
    private var lastTop = Int.MIN_VALUE
    private var lastWidth = -1
    private var lastHeight = -1
    private var lastBlur = Float.NaN
    private var lastBackdrop = Int.MIN_VALUE
    private var placed = false
    private val glassLocation = IntArray(2)
    private val rootLocation = IntArray(2)

    fun apply(attr: ViewAttr) {
        clearStyle = attr.glassStyle == "clear"
        blurPx = OTSize.create(if (clearStyle) "1" else "8").valueFloat.coerceAtLeast(0f)
        val tint = if (attr.glassTint != null) {
            parseTint(attr.glassTint)
        } else if (clearStyle) {
            0x0AFFFFFF
        } else {
            0x2EFFFFFF
        }
        val highlight = if (clearStyle) 0.35f else 0.16f
        val shadowPx = OTSize.create(if (clearStyle) "2" else "6").valueFloat.coerceAtLeast(0f)
        val refractionPx = OTSize.create(if (clearStyle) "18" else "12").valueFloat
        val dispersion = if (clearStyle) 0.22f else 0.1f
        bevelPx = OTSize.create(if (clearStyle) "24" else "16").valueFloat.coerceAtLeast(1f)
        frostPx = OTSize.create(if (clearStyle) "0" else "6").valueFloat.coerceAtLeast(0f)
        // 采样要比玻璃大一圈，折射才能把外面的画面拉进来。
        padPx = refractionPx * 1.5f + frostPx + OTSize.create("6").valueFloat
        val radii = StyleConverter.borderRadius(attr)?.value ?: FloatArray(8)
        val borderWidth = attr.borderWidth
        val borderColor = attr.borderColor?.let { raw ->
            runCatching { Color.parseColor(raw) }.getOrNull()
        }
        val solidStroke = borderColor != null && borderWidth != null
        val strokeWidth = if (solidStroke) {
            OTSize.create(borderWidth!!).valueFloat
        } else {
            0f
        }
        drawable.setAppearance(
            tint = tint,
            highlight = highlight,
            clear = clearStyle,
            interactive = attr.glassInteractive == "true",
            radii = radii,
            strokeColor = borderColor ?: Color.WHITE,
            strokeWidth = strokeWidth,
            solidStroke = solidStroke,
            refractionPx = refractionPx,
            dispersion = dispersion
        )
        applyShape(radii, shadowPx)
        captures = 0
        placed = false
        host.invalidate()
    }

    override fun onPreDraw(): Boolean {
        if (capturing) {
            return true
        }
        if (!host.isShown || host.width == 0 || host.height == 0 || !host.isLaidOut) {
            drawable.setFallback()
            return true
        }
        host.getLocationInWindow(glassLocation)
        val backdrop = backdropOffset()
        val moved = !placed ||
            kotlin.math.abs(glassLocation[0] - lastLeft) > 6 ||
            kotlin.math.abs(glassLocation[1] - lastTop) > 6 ||
            host.width != lastWidth ||
            host.height != lastHeight ||
            blurPx != lastBlur ||
            kotlin.math.abs(backdrop - lastBackdrop) > 2
        if (!moved && captures >= 2) {
            return true
        }
        val root = host.rootView
        if (root.width == 0 || root.height == 0) {
            drawable.setFallback()
            return true
        }
        capturing = true
        val previousAlpha = host.alpha
        val hidden = ArrayList<View>()
        // 先藏起自己和画在上面的兄弟，快照里才是背后的内容。
        host.alpha = 0f
        hideViewsInFront(hidden)
        try {
            val expandedW = host.width + padPx * 2f
            val expandedH = host.height + padPx * 2f
            val sample = sampleSize(expandedW.roundToInt(), expandedH.roundToInt())
            val bitmap = ensureBuffer(sample.first, sample.second)
            val canvas = Canvas(bitmap)
            canvas.drawColor(Color.TRANSPARENT, android.graphics.PorterDuff.Mode.CLEAR)
            drawRoot(canvas, root, bitmap.width, expandedW)
            val sampleRadius = if (expandedW <= 1f) {
                0f
            } else {
                blurPx * bitmap.width / expandedW
            }
            root.getLocationInWindow(rootLocation)
            val leftRoom = (glassLocation[0] - rootLocation[0]).toFloat().coerceAtLeast(0f)
            val topRoom = (glassLocation[1] - rootLocation[1]).toFloat().coerceAtLeast(0f)
            val rightRoom = (root.width - (glassLocation[0] - rootLocation[0] + host.width)).toFloat().coerceAtLeast(0f)
            val bottomRoom = (root.height - (glassLocation[1] - rootLocation[1] + host.height)).toFloat().coerceAtLeast(0f)
            drawable.setBackdrop(
                bitmap,
                sampleRadius,
                padPx,
                bevelPx,
                frostPx,
                leftRoom,
                topRoom,
                rightRoom,
                bottomRoom
            )
            rememberFrame()
        } catch (_: Throwable) {
            drawable.setFallback()
            rememberFrame()
        } finally {
            restoreHidden(hidden)
            host.alpha = previousAlpha
            capturing = false
        }
        return true
    }

    override fun onViewAttachedToWindow(v: View) {
        val tree = v.viewTreeObserver
        if (tree.isAlive) {
            tree.addOnPreDrawListener(this)
            observer = tree
        }
        captures = 0
    }

    override fun onViewDetachedFromWindow(v: View) {
        val tree = observer
        if (tree != null && tree.isAlive) {
            tree.removeOnPreDrawListener(this)
        }
        observer = null
        drawable.release()
        buffer?.takeIf { !it.isRecycled }?.recycle()
        buffer = null
        captures = 0
        placed = false
    }

    private fun rememberFrame() {
        lastLeft = glassLocation[0]
        lastTop = glassLocation[1]
        lastWidth = host.width
        lastHeight = host.height
        lastBlur = blurPx
        lastBackdrop = backdropOffset()
        placed = true
        captures += 1
    }

    private fun backdropOffset(): Int {
        var cursor: android.view.ViewParent? = host.parent
        var offset = 0
        while (cursor is View) {
            val view: View = cursor
            val picture = view.background
            if (picture is PanningBitmapDrawable) {
                offset += picture.offsetPx()
            }
            cursor = view.parent
        }
        return offset
    }

    private fun drawRoot(canvas: Canvas, root: View, sampleWidth: Int, expandedWidth: Float) {
        root.getLocationInWindow(rootLocation)
        val dx = glassLocation[0] - rootLocation[0] - padPx
        val dy = glassLocation[1] - rootLocation[1] - padPx
        val scale = sampleWidth.toFloat() / expandedWidth.coerceAtLeast(1f)
        canvas.save()
        canvas.scale(scale, scale)
        canvas.translate(-dx, -dy)
        canvas.clipRect(dx, dy, dx + expandedWidth, dy + host.height + padPx * 2f)
        root.draw(canvas)
        canvas.restore()
    }

    private fun hideViewsInFront(hidden: MutableList<View>) {
        var current: View = host
        var parent = current.parent as? ViewGroup
        while (parent != null) {
            val index = parent.indexOfChild(current)
            if (index >= 0) {
                for (i in index + 1 until parent.childCount) {
                    markGone(parent.getChildAt(i), hidden)
                }
                val hostZ = current.z
                for (i in 0 until index) {
                    val child = parent.getChildAt(i)
                    if (child.z > hostZ) {
                        markGone(child, hidden)
                    }
                }
            }
            if (parent === host.rootView) {
                break
            }
            current = parent
            parent = current.parent as? ViewGroup
        }
    }

    private fun markGone(child: View, hidden: MutableList<View>) {
        if (child.visibility == View.VISIBLE) {
            child.visibility = View.GONE
            hidden.add(child)
        }
    }

    private fun restoreHidden(hidden: List<View>) {
        for (child in hidden) {
            child.visibility = View.VISIBLE
        }
    }

    private fun ensureBuffer(width: Int, height: Int): Bitmap {
        val current = buffer
        if (current != null && !current.isRecycled && current.width == width && current.height == height) {
            return current
        }
        drawable.release()
        current?.takeIf { !current.isRecycled }?.recycle()
        val created = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        buffer = created
        return created
    }

    private fun sampleSize(width: Int, height: Int): Pair<Int, Int> {
        val maxSide = max(width, height).toFloat().coerceAtLeast(1f)
        val scale = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            min(1f, 840f / maxSide)
        } else if (clearStyle) {
            min(0.42f, 220f / maxSide)
        } else {
            min(0.28f, 160f / maxSide)
        }
        val sampleWidth = max(1, (width * scale).roundToInt())
        val sampleHeight = max(1, (height * scale).roundToInt())
        return sampleWidth to sampleHeight
    }

    private fun applyShape(radii: FloatArray, shadowPx: Float) {
        val uniform = if (radii.size == 8) radii[0] else 0f
        val same = radii.size == 8 &&
            radii[2] == uniform &&
            radii[4] == uniform &&
            radii[6] == uniform
        val modernPath = !same && Build.VERSION.SDK_INT >= 30
        host.outlineProvider = object : ViewOutlineProvider() {
            override fun getOutline(view: View, outline: Outline) {
                if (view.width == 0 || view.height == 0) {
                    return
                }
                if (!same && Build.VERSION.SDK_INT >= 30) {
                    val path = Path()
                    path.addRoundRect(
                        RectF(0f, 0f, view.width.toFloat(), view.height.toFloat()),
                        radii,
                        Path.Direction.CW
                    )
                    outline.setPath(path)
                } else {
                    outline.setRoundRect(0, 0, view.width, view.height, uniform)
                }
            }
        }
        host.elevation = shadowPx
        if (Build.VERSION.SDK_INT >= 28) {
            host.outlineSpotShadowColor = 0x2E000000
            host.outlineAmbientShadowColor = 0x14000000
        }
        val layout = host as? OTAbsoluteLayout
        if (layout != null && !same && !modernPath) {
            layout.clipContentToRadii(radii)
        } else {
            layout?.clearSizedCornerClip()
        }
        host.clipToOutline = (same && uniform > 0f) || modernPath
        host.invalidateOutline()
    }

    private fun loosenParents() {
        var parent = host.parent
        while (parent is ViewGroup && parent !is NestedScrollView) {
            if (parent is OTAbsoluteLayout) {
                parent.clipChildren = false
            }
            parent = parent.parent
        }
    }

    companion object {
        fun attach(view: View, attr: ViewAttr): LiquidGlassController {
            val existing = view.getTag(R.id.ot_liquid_glass) as? LiquidGlassController
            val controller = existing ?: LiquidGlassController(view).also { created ->
                view.setTag(R.id.ot_liquid_glass, created)
                view.background = created.drawable
                view.addOnAttachStateChangeListener(created)
                if (view.isAttachedToWindow) {
                    created.onViewAttachedToWindow(view)
                }
                created.loosenParents()
            }
            if (view.background !== controller.drawable) {
                view.background = controller.drawable
            }
            controller.apply(attr)
            return controller
        }

        fun release(view: View) {
            val controller = view.getTag(R.id.ot_liquid_glass) as? LiquidGlassController ?: return
            view.removeOnAttachStateChangeListener(controller)
            controller.onViewDetachedFromWindow(view)
            view.setTag(R.id.ot_liquid_glass, null)
            if (view.background === controller.drawable) {
                view.background = null
            }
            view.elevation = 0f
            view.outlineProvider = ViewOutlineProvider.BACKGROUND
            view.clipToOutline = false
            (view as? OTAbsoluteLayout)?.clearSizedCornerClip()
        }

        private fun parseTint(raw: String?): Int {
            if (raw.isNullOrBlank() || raw == "transparent") {
                return Color.TRANSPARENT
            }
            return runCatching { Color.parseColor(raw) }.getOrDefault(0x38FFFFFF)
        }
    }
}
