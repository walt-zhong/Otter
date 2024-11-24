package com.dynamic.otter.render.view.basic.adapter

import android.graphics.Rect
import android.view.View
import androidx.recyclerview.widget.RecyclerView

class ItemSpaceDecoration(
    private var space: Int = 0,
    private var startSpace: Int = 0,
    private var topSpace: Int = 0,
    private var endSpace: Int = 0,
    private var bottomSpace: Int = 0
) : RecyclerView.ItemDecoration() {
    override fun getItemOffsets(
        outRect: Rect,
        view: View,
        parent: RecyclerView,
        state: RecyclerView.State
    ) {
        if(space > 0){
            outRect.left = space
            outRect.right = space
            outRect.bottom = space
        }

        if(startSpace > 0 ){
            outRect.left = startSpace
        }
        if(endSpace > 0){
            outRect.right = endSpace
        }

        if(bottomSpace > 0 ){
            outRect.bottom = bottomSpace
        }

        if(parent.getChildAdapterPosition(view) == 0){
            outRect.top = 0
        }else{
            if(space > 0 ){
                outRect.top = space
            }

            if(topSpace > 0){
                outRect.top = topSpace
            }
        }
       // super.getItemOffsets(outRect, view, parent, state)
    }


}