package com.dynamic.otter.render.view.basic

import android.content.Context
import android.util.AttributeSet
import android.view.View
import androidx.annotation.Keep

@Keep
class Spacer : View {
    constructor(context: Context) : super(context)
    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs)
    constructor(context: Context, attrs: AttributeSet?, defStyle: Int) : super(
        context,
        attrs,
        defStyle
    )
}