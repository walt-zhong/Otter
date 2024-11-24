package com.dynamic.otter.render.view.basic

import android.content.Context
import android.util.AttributeSet
import androidx.annotation.Keep

@Keep
class Row : OTAbsoluteLayout {
    constructor(context: Context) : super(context)

    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs)

    constructor(context: Context, attrs: AttributeSet?, defStyleAttr: Int) : super(
        context, attrs, defStyleAttr
    )
}