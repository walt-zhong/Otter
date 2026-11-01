package com.dynamic.otter.render.view.basic.adapter

import android.annotation.SuppressLint
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.recyclerview.widget.RecyclerView
import com.alibaba.fastjson.JSONArray
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.OTEngine
import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.render.node.OTNode
import com.dynamic.otter.render.node.VDomNode
import com.dynamic.otter.render.view.OTViewTreeCreator
import com.dynamic.otter.render.view.basic.OTItemView
import kotlin.math.roundToInt

class OTListAdapter(
    itemTemplate: VDomNode,
    viewport: OTEngine.OTViewPortSize,
    private val templateContext: TemplateContext,
    private val listDirection: Int = RecyclerView.VERTICAL,
    private val itemPadding: Int = 0
) : RecyclerView.Adapter<OTViewHolder>() {
    private var listData: JSONArray = JSONArray()
    private var itemTemplate: VDomNode = itemTemplate
    private var viewport: OTEngine.OTViewPortSize = viewport

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): OTViewHolder {
        val itemContainer = OTItemView(parent.context)
        itemContainer.layoutParams = FrameLayout.LayoutParams(0, 0)
        return OTViewHolder(itemContainer)
    }

    override fun getItemCount(): Int = listData.size

    override fun onBindViewHolder(holder: OTViewHolder, position: Int) {
        val itemData = if (position < listData.size) {
            listData[position] as JSONObject
        } else {
            JSONObject()
        }
        val itemNode = measuredItemNode(itemData)
        val itemContainer = holder.itemView as OTItemView
        val gap = if (position == listData.size - 1) 0 else itemPadding
        val height = WrapTextHeight.contentHeight(itemNode)
        itemContainer.layoutParams = itemLayoutParams(itemNode, gap, height)
        itemContainer.removeAllViews()
        try {
            val itemView = OTViewTreeCreator.buildAndroidItemView(itemNode, templateContext, itemData)
            val params = itemView.layoutParams
            if (params != null && params.height < height) {
                params.height = height
            }
            itemContainer.addView(itemView)
        } finally {
            itemNode.release()
        }
    }

    override fun onViewRecycled(holder: OTViewHolder) {
        (holder.itemView as? ViewGroup)?.removeAllViews()
    }

    private fun measuredItemNode(itemData: JSONObject): OTNode {
        val itemNode = OTEngine.instance.createNodeTree(itemTemplate, viewport)
        WrapTextHeight.settle(itemNode, itemData, viewport)
        return itemNode
    }

    private fun itemLayoutParams(node: OTNode, gap: Int, height: Int): FrameLayout.LayoutParams {
        val layout = node.stretchNode.layoutByPrepareView
        val params = FrameLayout.LayoutParams(
            layout?.width?.roundToInt() ?: 0,
            height
        )
        if (listDirection == RecyclerView.HORIZONTAL) {
            params.rightMargin = gap
        } else {
            params.bottomMargin = gap
        }
        return params
    }

    @SuppressLint("NotifyDataSetChanged")
    fun setData(data: JSONArray) {
        listData = data
        notifyDataSetChanged()
    }

    fun updateBinding(template: VDomNode?, viewport: OTEngine.OTViewPortSize, data: JSONArray) {
        if (template != null) {
            itemTemplate = template
        }
        this.viewport = viewport
        setData(data)
    }

    fun isSameData(data: JSONArray): Boolean = listData === data

    fun appendItem(item: JSONObject) {
        listData.add(item)
        notifyItemInserted(listData.size - 1)
    }

    fun itemField(index: Int, key: String): String {
        if (index !in 0 until listData.size) {
            return ""
        }
        return (listData[index] as? JSONObject)?.getString(key).orEmpty()
    }

    fun updateItem(index: Int, fields: Map<String, String>) {
        if (index !in 0 until listData.size) {
            return
        }
        val item = listData[index] as? JSONObject ?: return
        fields.forEach { (key, value) -> item[key] = value }
        notifyItemChanged(index)
    }

    fun removeItem(index: Int) {
        if (index !in 0 until listData.size) {
            return
        }
        listData.removeAt(index)
        notifyItemRemoved(index)
    }
}
