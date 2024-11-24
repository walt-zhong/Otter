package com.dynamic.otter.template

import app.visly.stretch.AlignContent
import app.visly.stretch.AlignItems
import app.visly.stretch.AlignSelf
import app.visly.stretch.Dimension
import app.visly.stretch.Direction
import app.visly.stretch.Display
import app.visly.stretch.FlexDirection
import app.visly.stretch.FlexWrap
import app.visly.stretch.JustifyContent
import app.visly.stretch.Overflow
import app.visly.stretch.PositionType
import app.visly.stretch.Rect
import app.visly.stretch.Size
import com.dynamic.otter.data.FlexBoxKey
import com.dynamic.otter.render.view.attr.ColumnAttr
import com.dynamic.otter.render.view.attr.ContainerAttr
import com.dynamic.otter.render.view.attr.RowAttr
import com.dynamic.otter.render.view.attr.ViewAttr

data class OTFlexBox(
    internal var display: Display? = null,
    internal var positionType: PositionType? = null,
    internal var direction: Direction? = null,
    internal var flexDirection: FlexDirection? = null,
    internal var flexWrap: FlexWrap? = null,
    internal var overflow: Overflow? = null,
    internal var alignItems: AlignItems? = null,
    internal var alignSelf: AlignSelf? = null,
    internal var alignContent: AlignContent? = null,
    internal var justifyContent: JustifyContent? = null,
    internal var position: Rect<OTSize?>? = null,
    internal var margin: Rect<OTSize?>? = null,
    internal var padding: Rect<OTSize?>? = null,
    internal var border: Rect<OTSize?>? = null,
    internal var flexGrow: Float? = null,
    internal var flexShrink: Float? = null,
    internal var flexBasis: OTSize? = null,
    internal var size: Size<OTSize?>? = null,
    internal var minSize: Size<OTSize?>? = null,
    internal var maxSize: Size<OTSize?>? = null,
    internal var aspectRation: Float? = null
) {
    private var finalSize: Size<Dimension>? = null
    private var paddingDimension: Rect<Dimension>? = null

    companion object {
        fun create(viewAttr: ViewAttr?): OTFlexBox {
            if (viewAttr == null) {
                return OTFlexBox()
            }

            val sdFlexBox = OTFlexBox()
            if (viewAttr is ColumnAttr) {
                sdFlexBox.flexDirection = FlexBoxConvert.flexDirection(FlexBoxKey.FLEXBOX_COLUMN)
            }

            // 如果是容器属性
            if (viewAttr is ContainerAttr) {
                sdFlexBox.justifyContent = viewAttr.justifyContent?.let {
                    FlexBoxConvert.justifyContent(
                        it
                    )
                }

                sdFlexBox.alignItems = viewAttr.alignItems?.let {
                    FlexBoxConvert.alignItems(it)
                }

                sdFlexBox.display = FlexBoxConvert.display(FlexBoxKey.FLEXBOX_FLEX)
            }

            if (viewAttr is RowAttr) {
                sdFlexBox.flexDirection = FlexBoxConvert.flexDirection(FlexBoxKey.FLEXBOX_ROW)
            }

            if (sdFlexBox.size == null) {
                sdFlexBox.size = Size(
                    OTSize.create(viewAttr.width),
                    OTSize.create(viewAttr.height)
                )
            }

            if (sdFlexBox.padding == null) {
                sdFlexBox.padding = StyleConverter.instance.padding(viewAttr)
            }

            return sdFlexBox
        }
    }

    val sizeForDimension: Size<Dimension>?
        get() {
            return if (size != null) {
                if (finalSize == null) {
                    finalSize = Size(
                        size?.width?.valueDimension ?: Dimension.Auto,
                        size?.height?.valueDimension ?: Dimension.Auto
                    )
                    finalSize
                } else {
                    finalSize
                }
            } else {
                null
            }
        }

    val paddingForDimension: Rect<Dimension>?
        get() {
            return if (paddingDimension == null) {
                paddingDimension = Rect(
                    padding?.start?.valueDimension ?: Dimension.Undefined,
                    padding?.end?.valueDimension ?: Dimension.Undefined,
                    padding?.top?.valueDimension ?: Dimension.Undefined,
                    padding?.bottom?.valueDimension ?: Dimension.Undefined
                )
                paddingDimension
            } else {
                paddingDimension
            }
        }
}