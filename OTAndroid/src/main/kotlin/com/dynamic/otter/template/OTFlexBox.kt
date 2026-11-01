package com.dynamic.otter.template

import app.visly.stretch.AlignItems
import app.visly.stretch.AlignSelf
import app.visly.stretch.Dimension
import app.visly.stretch.Display
import app.visly.stretch.FlexDirection
import app.visly.stretch.FlexWrap
import app.visly.stretch.JustifyContent
import app.visly.stretch.Rect
import app.visly.stretch.Size
import com.dynamic.otter.render.view.attr.ContainerAttr
import com.dynamic.otter.render.view.attr.ViewAttr

data class OTFlexBox(
    internal var display: Display? = null,
    internal var flexDirection: FlexDirection? = null,
    internal var alignItems: AlignItems? = null,
    internal var justifyContent: JustifyContent? = null,
    internal var padding: Rect<OTSize?>? = null,
    internal var size: Size<OTSize?>? = null,
    internal var flexGrow: Float = 0f,
    internal var margin: Rect<OTSize?>? = null,
    internal var minSize: Size<OTSize?>? = null,
    internal var maxSize: Size<OTSize?>? = null,
    internal var aspectRatio: Float? = null,
    internal var flexWrap: FlexWrap? = null,
    internal var alignSelf: AlignSelf? = null
) {
    val sizeForDimension: Size<Dimension>?
        get() {
            val current = size ?: return null
            return Size(
                current.width?.valueDimension ?: Dimension.Auto,
                current.height?.valueDimension ?: Dimension.Auto
            )
        }

    val paddingForDimension: Rect<Dimension>
        get() = Rect(
            padding?.start?.valueDimension ?: Dimension.Undefined,
            padding?.end?.valueDimension ?: Dimension.Undefined,
            padding?.top?.valueDimension ?: Dimension.Undefined,
            padding?.bottom?.valueDimension ?: Dimension.Undefined
        )

    val marginForDimension: Rect<Dimension>
        get() = Rect(
            margin?.start?.valueDimension ?: Dimension.Undefined,
            margin?.end?.valueDimension ?: Dimension.Undefined,
            margin?.top?.valueDimension ?: Dimension.Undefined,
            margin?.bottom?.valueDimension ?: Dimension.Undefined
        )

    val minSizeForDimension: Size<Dimension>?
        get() = boundForDimension(minSize)

    val maxSizeForDimension: Size<Dimension>?
        get() = boundForDimension(maxSize)

    companion object {
        fun create(viewAttr: ViewAttr): OTFlexBox {
            val flexBox = OTFlexBox(
                display = if (viewAttr.visible == "false") Display.None else Display.Flex,
                size = Size(
                    OTSize.create(viewAttr.width),
                    OTSize.create(viewAttr.height)
                ),
                padding = StyleConverter.padding(viewAttr),
                margin = margin(viewAttr),
                minSize = boundSize(viewAttr.minWidth, viewAttr.minHeight),
                maxSize = boundSize(viewAttr.maxWidth, viewAttr.maxHeight),
                flexGrow = viewAttr.flexGrow,
                aspectRatio = viewAttr.aspectRatio?.toFloatOrNull(),
                alignSelf = viewAttr.alignSelf?.let(::toAlignSelf)
            )
            if (viewAttr is ContainerAttr) {
                flexBox.flexDirection = viewAttr.flexDirection
                flexBox.justifyContent = viewAttr.justifyContent?.let(FlexBoxConvert::justifyContent)
                flexBox.alignItems = viewAttr.alignItems?.let(FlexBoxConvert::alignItems)
                flexBox.flexWrap = viewAttr.flexWrap?.let(::toFlexWrap)
            }
            return flexBox
        }

        private fun margin(viewAttr: ViewAttr): Rect<OTSize?>? {
            val uniform = viewAttr.margin?.let { OTSize.create(it) }
            val start = viewAttr.marginStart?.let { OTSize.create(it) }
            val end = viewAttr.marginEnd?.let { OTSize.create(it) }
            val top = viewAttr.marginTop?.let { OTSize.create(it) }
            val bottom = viewAttr.marginBottom?.let { OTSize.create(it) }
            if (uniform == null && start == null && end == null && top == null && bottom == null) {
                return null
            }
            val fallback = uniform ?: OTSize.Undefined
            return Rect(
                start ?: fallback,
                end ?: fallback,
                top ?: fallback,
                bottom ?: fallback
            )
        }

        private fun boundSize(width: String?, height: String?): Size<OTSize?>? {
            if (width == null && height == null) {
                return null
            }
            return Size(width?.let(OTSize::create), height?.let(OTSize::create))
        }

        private fun boundForDimension(size: Size<OTSize?>?): Size<Dimension>? {
            val current = size ?: return null
            return Size(
                current.width?.valueDimension ?: Dimension.Auto,
                current.height?.valueDimension ?: Dimension.Auto
            )
        }

        private fun toAlignSelf(value: String): AlignSelf? = when (value) {
            "start" -> AlignSelf.FlexStart
            "end" -> AlignSelf.FlexEnd
            "center" -> AlignSelf.Center
            "stretch" -> AlignSelf.Stretch
            else -> null
        }

        private fun toFlexWrap(value: String): FlexWrap? = when (value) {
            "wrap" -> FlexWrap.Wrap
            "nowrap" -> FlexWrap.NoWrap
            else -> null
        }
    }
}
