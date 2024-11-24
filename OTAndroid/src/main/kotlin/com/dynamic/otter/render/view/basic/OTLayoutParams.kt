package com.dynamic.otter.render.view.basic

import android.content.Context
import android.content.res.TypedArray
import android.util.AttributeSet
import android.view.ViewGroup
import androidx.annotation.Keep
import com.dynamic.outter.R

@Keep
class OTLayoutParams : ViewGroup.LayoutParams {
    var x = 0
    var y = 0

    constructor(width: Int, height: Int, x: Int, y: Int) : super(width, height) {
        this.x = x;
        this.y = y
    }

    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs) {
        val a: TypedArray = context.obtainStyledAttributes(
            attrs,
            R.styleable.SDAbsoluteLayout_Layout
        )
        x = a.getDimensionPixelOffset(
            R.styleable.SDAbsoluteLayout_Layout_layout_x, 0
        )
        y = a.getDimensionPixelOffset(
            R.styleable.SDAbsoluteLayout_Layout_layout_y, 0
        )
        a.recycle()
    }

    constructor(source: ViewGroup.LayoutParams?) : super(source) {

    }
}