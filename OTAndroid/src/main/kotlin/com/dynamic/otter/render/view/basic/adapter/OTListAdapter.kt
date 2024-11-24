package com.dynamic.otter.render.view.basic.adapter

import android.annotation.SuppressLint
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.recyclerview.widget.RecyclerView
import app.visly.stretch.Layout
import com.alibaba.fastjson.JSONArray
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.OTEngine
import com.dynamic.otter.OTEngine.OTViewPortSize
import com.dynamic.otter.data.ListContainerData
import com.dynamic.otter.render.node.OTNode
import com.dynamic.otter.render.node.VDomNode
import com.dynamic.otter.render.view.OTViewTreeCreator
import com.dynamic.otter.render.view.basic.OTItemView
import com.dynamic.otter.utils.ScreenUtils

class OTListAdapter(
    private val parentId: String,
    private val listDirection: Int = RecyclerView.VERTICAL,
    private val itemPadding: Int = 0
) : RecyclerView.Adapter<OTViewHolder>() {
    private var listData: JSONArray = JSONArray()
    private var sdNode: OTNode? = null

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): OTViewHolder {
        return createOTViewHolder(parent, viewType)
    }

    private fun createOTViewHolder(parent: ViewGroup, viewType: Int): OTViewHolder {
        // 设置展示的视图窗口大小,默认为屏幕的宽高
        val vSDViewPortSize = OTViewPortSize(
            ScreenUtils.getScreenWidthPx(parent.context),
            ScreenUtils.getScreenHeightPx(parent.context)
        )
        val vDomNode: VDomNode? = ListContainerData.listItemVNodeMap[parentId]
        if (vDomNode != null) {
            sdNode = OTEngine.instance.createNodeTree(vDomNode, vSDViewPortSize)
        }

        val itemLayoutParam = genItemContainerSize(sdNode?.stretchNode?.layoutByPrepareView)
        val itemContainer = OTItemView(parent.context)
        itemContainer.layoutParams = itemLayoutParam

        return OTViewHolder(itemContainer)
    }

    private fun genItemContainerSize(containerLayout: Layout?): FrameLayout.LayoutParams {
        val itemContainerHeight = containerLayout?.height ?: 0F
        val itemContainerWidth = containerLayout?.width ?: 0F

        return FrameLayout.LayoutParams(
            itemContainerWidth.toInt(),
            itemContainerHeight.toInt()
        )
    }

    override fun getItemCount(): Int {
        return listData.size
    }

    override fun onBindViewHolder(holder: OTViewHolder, position: Int) {
        bindSDViewHolder(holder, position)
    }

    private fun bindSDViewHolder(holder: OTViewHolder, position: Int) {
        val listContainerId = parentId
        val context = holder.itemView.context
        val itemData = if (position < listData.size) {
            listData[position] as JSONObject
        } else {
            JSONObject()
        }

        val itemContainer = holder.itemView as OTItemView
        val itemLayoutParam = genItemContainerSize(sdNode?.stretchNode?.layoutByPrepareView)
        if (position != listData.size - 1) {
            if (listDirection == RecyclerView.HORIZONTAL) {
                itemLayoutParam.rightMargin = itemPadding
            } else if (listDirection == RecyclerView.VERTICAL) {
                itemLayoutParam.bottomMargin = itemPadding
            }

            itemContainer.layoutParams = itemLayoutParam
        }


        // 设置展示的视图窗口大小,默认为屏幕的宽高
        val vSDViewPortSize = OTViewPortSize(
            ScreenUtils.getScreenWidthPx(context),
            ScreenUtils.getScreenHeightPx(context)
        )

        val vDomNode: VDomNode? = ListContainerData.listItemVNodeMap[listContainerId]

        val itemView: View? = if (vDomNode != null) {
            sdNode?.let { OTViewTreeCreator.buildAndroidItemView(it, context, itemData) }
        } else {
            null
        }

        ListContainerData.listItemAndroidViewMap[listContainerId] = itemView!!
        itemContainer.addView(itemView, 0)
    }


    @SuppressLint("NotifyDataSetChanged")
    fun setData(data: JSONArray) {
        listData = data
        notifyDataSetChanged()
    }
}