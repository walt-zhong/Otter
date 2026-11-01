package com.dynamic.otter.render.view.basic.adapter

import android.content.Context
import android.graphics.Paint
import android.graphics.Typeface
import android.os.Build
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import app.visly.stretch.Dimension
import app.visly.stretch.Size
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.OTEngine
import com.dynamic.otter.data.TemplateKey
import com.dynamic.otter.render.node.NodeUtils
import com.dynamic.otter.render.node.OTNode
import com.dynamic.otter.render.utils.FunctionExt.extractExpValue
import com.dynamic.otter.render.view.attr.TextAttr
import com.dynamic.otter.render.view.basic.Text
import com.dynamic.otter.template.OTSize
import com.dynamic.otter.template.StyleConverter
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

internal object WrapTextHeight {
    fun settle(root: OTNode, itemData: JSONObject, viewport: OTEngine.OTViewPortSize) {
        val size = Size(viewport.width, viewport.height)
        NodeUtils.computeNodeTreeByPrepareView(root, size)
        var guard = 0
        while (guard < 4 && apply(root, itemData, viewport)) {
            NodeUtils.computeNodeTreeByPrepareView(root, size)
            guard++
        }
    }

    fun apply(root: OTNode, itemData: JSONObject, viewport: OTEngine.OTViewPortSize): Boolean {
        return applyNode(root, itemData, viewport)
    }

    fun contentHeight(node: OTNode): Int = subtreeBottom(node)

    private fun applyNode(
        node: OTNode,
        itemData: JSONObject,
        viewport: OTEngine.OTViewPortSize
    ): Boolean {
        var changed = false
        val attr = node.attr as? TextAttr
        if (attr != null && (isWrap(attr.width) || isWrap(attr.height))) {
            val measured = measure(node, attr, itemData, viewport)
            if (assignSize(node, measured)) {
                changed = true
            }
        }
        node.children.forEach { child ->
            if (applyNode(child, itemData, viewport)) {
                changed = true
            }
        }
        return changed
    }

    private fun isWrap(height: String): Boolean {
        return height == "wrap" || height == TemplateKey.OT_WRAP_CONTENT
    }

    private fun measure(
        node: OTNode,
        attr: TextAttr,
        itemData: JSONObject,
        viewport: OTEngine.OTViewPortSize
    ): Measured {
        val padding = StyleConverter.padding(attr)
        val start = padding?.start?.valueInt ?: 0
        val end = padding?.end?.valueInt ?: 0
        val top = padding?.top?.valueInt ?: 0
        val bottom = padding?.bottom?.valueInt ?: 0
        val wrapWidth = isWrap(attr.width)
        val wrapHeight = isWrap(attr.height)
        // 行里的 width:wrap 没有 MeasureFunc，主轴尺寸会是 0，文字视图就被裁成一条缝。
        // 高度仍按文字测量；宽度用父级内容宽做上限，再收成最长一行。
        val laidOut = node.stretchNode.layoutByPrepareView?.width?.takeIf { it > 0f }
        val maxBox = if (wrapWidth || laidOut == null) {
            maxWidthForWrap(node, viewport) ?: laidOut ?: 0f
        } else {
            laidOut
        }
        val contentWidth = (maxBox - start - end).roundToInt().coerceAtLeast(0)
        val text = attr.text.extractExpValue(itemData)
        val context = OTEngine.instance.readyContext()
        if (context != null) {
            return measureWithText(
                context, attr, text, contentWidth, start, end, top, bottom, wrapWidth, wrapHeight, maxBox
            )
        }
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG)
        paint.typeface = typefaceFor(attr.fontWeight)
        paint.textSize = OTSize.create(attr.textSize).valueFloat.coerceAtLeast(1f)
        val oneLine = ceil((paint.fontMetrics.descent - paint.fontMetrics.ascent).toDouble())
            .toInt()
            .coerceAtLeast(1)
        val layoutHeight: Int
        val lineWidth: Float
        if (contentWidth <= 0) {
            layoutHeight = oneLine
            lineWidth = paint.measureText(text)
        } else {
            val builder = StaticLayout.Builder.obtain(text, 0, text.length, paint, contentWidth)
                .setIncludePad(false)
                .setLineSpacing(0f, 1f)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                builder.setUseLineSpacingFromFallbacks(true)
            }
            val limit = lineLimit(attr)
            if (limit > 0) {
                builder.setMaxLines(limit)
            }
            val layout = builder.build()
            layoutHeight = ceil(layout.height.toDouble()).toInt().coerceAtLeast(oneLine)
            var widest = 0f
            for (index in 0 until layout.lineCount) {
                widest = max(widest, layout.getLineWidth(index))
            }
            lineWidth = widest
        }
        val widthPx = if (wrapWidth) {
            val wanted = ceil(lineWidth.toDouble()).toFloat() + start + end
            if (maxBox > 0f) min(wanted, maxBox) else wanted
        } else {
            null
        }
        val heightPx = if (wrapHeight) {
            (layoutHeight + top + bottom).toFloat()
        } else {
            null
        }
        return Measured(widthPx, heightPx)
    }

    private fun measureWithText(
        context: Context,
        attr: TextAttr,
        text: String,
        contentWidth: Int,
        start: Int,
        end: Int,
        top: Int,
        bottom: Int,
        wrapWidth: Boolean,
        wrapHeight: Boolean,
        maxBox: Float
    ): Measured {
        val view = Text(context)
        view.includeFontPadding = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            view.isFallbackLineSpacing = true
        }
        view.setTextSize(
            TypedValue.COMPLEX_UNIT_PX,
            OTSize.create(attr.textSize).valueFloat.coerceAtLeast(1f)
        )
        view.typeface = typefaceFor(attr.fontWeight)
        view.setPadding(start, top, end, bottom)
        val limit = lineLimit(attr)
        view.maxLines = if (limit > 0) limit else Integer.MAX_VALUE
        view.ellipsize = if (attr.ellipsis) TextUtils.TruncateAt.END else null
        view.gravity = Gravity.TOP or Gravity.START
        view.text = text
        val border = contentWidth + start + end
        val widthMode = when {
            border <= 0 -> View.MeasureSpec.UNSPECIFIED
            wrapWidth -> View.MeasureSpec.AT_MOST
            else -> View.MeasureSpec.EXACTLY
        }
        view.measure(
            View.MeasureSpec.makeMeasureSpec(if (border > 0) border else 0, widthMode),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )
        val widthPx = if (wrapWidth) {
            val wanted = view.measuredWidth.toFloat()
            if (maxBox > 0f) min(wanted, maxBox) else wanted
        } else {
            null
        }
        val heightPx = if (wrapHeight) view.measuredHeight.toFloat().coerceAtLeast(1f) else null
        return Measured(widthPx, heightPx)
    }

    private fun maxWidthForWrap(node: OTNode, viewport: OTEngine.OTViewPortSize): Float? {
        val parent = node.parentNode
        val parentWidth = parent?.stretchNode?.layoutByPrepareView?.width?.takeIf { it > 0f }
            ?: return viewport.width?.takeIf { it > 0f }
        val padding = StyleConverter.padding(parent.attr)
        val start = padding?.start?.valueInt ?: 0
        val end = padding?.end?.valueInt ?: 0
        val marginStart = edge(node.attr?.margin, node.attr?.marginStart)
        val marginEnd = edge(node.attr?.margin, node.attr?.marginEnd)
        return (parentWidth - start - end - marginStart - marginEnd).takeIf { it > 0f }
    }

    private fun edge(uniform: String?, specific: String?): Int {
        val raw = specific ?: uniform ?: return 0
        return OTSize.create(raw).valueInt
    }

    private fun typefaceFor(weight: String?): Typeface {
        return when (weight?.trim()) {
            "bold" -> Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            "medium" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                Typeface.create(Typeface.DEFAULT, 500, false)
            } else {
                Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            }
            else -> Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
        }
    }

    private fun lineLimit(attr: TextAttr): Int {
        val maxLines = attr.maxLines
        if (maxLines != null && maxLines > 0) {
            return maxLines
        }
        if (attr.ellipsis) {
            return 1
        }
        return 0
    }

    private fun assignSize(node: OTNode, measured: Measured): Boolean {
        if (measured.width == null && measured.height == null) {
            return false
        }
        val stretch = node.stretchNode.node ?: return false
        val style = stretch.getStyle()
        val nextWidth = measured.width?.let { Dimension.Points(it) } ?: style.size.width
        val nextHeight = measured.height?.let { Dimension.Points(it) } ?: style.size.height
        if (sameDimension(style.size.width, nextWidth) && sameDimension(style.size.height, nextHeight)) {
            return false
        }
        style.size = Size(nextWidth, nextHeight)
        style.safeFree()
        style.safeInit()
        return stretch.safeSetStyle(style)
    }

    private fun sameDimension(current: Dimension, next: Dimension): Boolean {
        if (current is Dimension.Points && next is Dimension.Points) {
            return abs(current.points - next.points) < 1f
        }
        return current == next
    }

    private class Measured(val width: Float?, val height: Float?)

    private fun subtreeBottom(node: OTNode): Int {
        val own = node.stretchNode.layoutByPrepareView?.height?.roundToInt() ?: 0
        var extent = own
        node.children.forEach { child ->
            val y = child.stretchNode.layoutByPrepareView?.y?.roundToInt() ?: 0
            extent = max(extent, y + subtreeBottom(child))
        }
        return extent
    }
}
