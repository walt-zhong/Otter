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
    private var itemNode: OTNode? = null

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): OTViewHolder {
        return createOtViewHolder(parent)
    }

    private fun createOtViewHolder(parent: ViewGroup): OTViewHolder {
        val viewPortSize = OTViewPortSize(
            ScreenUtils.getScreenWidthPx(parent.context),
            ScreenUtils.getScreenHeightPx(parent.context)
        )
        val vDomNode: VDomNode? = ListContainerData.listItemVNodeMap[parentId]
        if (vDomNode != null) {
            itemNode = OTEngine.instance.createNodeTree(vDomNode, viewPortSize)
        }

        val itemContainer = OTItemView(parent.context)
        itemContainer.layoutParams = genItemContainerSize(itemNode?.stretchNode?.layoutByPrepareView)
        return OTViewHolder(itemContainer)
    }

    private fun genItemContainerSize(containerLayout: Layout?): FrameLayout.LayoutParams {
        val height = containerLayout?.height ?: 0F
        val width = containerLayout?.width ?: 0F
        return FrameLayout.LayoutParams(width.toInt(), height.toInt())
    }

    override fun getItemCount(): Int = listData.size

    override fun onBindViewHolder(holder: OTViewHolder, position: Int) {
        bindItem(holder, position)
    }

    private fun bindItem(holder: OTViewHolder, position: Int) {
        val context = holder.itemView.context
        val itemData = if (position < listData.size) {
            listData[position] as JSONObject
        } else {
            JSONObject()
        }

        val itemContainer = holder.itemView as OTItemView
        val itemLayoutParam = genItemContainerSize(itemNode?.stretchNode?.layoutByPrepareView)
        if (position != listData.size - 1) {
            if (listDirection == RecyclerView.HORIZONTAL) {
                itemLayoutParam.rightMargin = itemPadding
            } else if (listDirection == RecyclerView.VERTICAL) {
                itemLayoutParam.bottomMargin = itemPadding
            }
            itemContainer.layoutParams = itemLayoutParam
        }

        val vDomNode = ListContainerData.listItemVNodeMap[parentId]
        val itemView: View? = if (vDomNode != null) {
            itemNode?.let { OTViewTreeCreator.buildAndroidItemView(it, context, itemData) }
        } else {
            null
        }

        itemContainer.addView(itemView!!, 0)
    }

    @SuppressLint("NotifyDataSetChanged")
    fun setData(data: JSONArray) {
        listData = data
        notifyDataSetChanged()
    }
}
