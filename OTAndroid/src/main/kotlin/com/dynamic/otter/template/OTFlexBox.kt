package com.dynamic.otter.template

import app.visly.stretch.AlignItems
import app.visly.stretch.Dimension
import app.visly.stretch.Display
import app.visly.stretch.FlexDirection
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
    internal var size: Size<OTSize?>? = null
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

    companion object {
        fun create(viewAttr: ViewAttr): OTFlexBox {
            val flexBox = OTFlexBox(
                size = Size(
                    OTSize.create(viewAttr.width),
                    OTSize.create(viewAttr.height)
                ),
                padding = StyleConverter.padding(viewAttr)
            )
            if (viewAttr is ContainerAttr) {
                flexBox.flexDirection = viewAttr.flexDirection
                flexBox.justifyContent = viewAttr.justifyContent?.let(FlexBoxConvert::justifyContent)
                flexBox.alignItems = viewAttr.alignItems?.let(FlexBoxConvert::alignItems)
                flexBox.display = Display.Flex
            }
            return flexBox
        }
    }
}
