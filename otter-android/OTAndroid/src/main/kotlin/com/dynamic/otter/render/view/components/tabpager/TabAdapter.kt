package com.dynamic.otter.render.view.components.tabpager

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView

abstract class TabAdapter<T> : RecyclerView.Adapter<TabViewHolder>(),
    ITabAdapter<T, TabViewHolder> {
    private var listBean: MutableList<T> = mutableListOf()
    private var positionSelectedLast = 0
    private var positionSelected = 0

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): TabViewHolder {
        val tabViewHolder = TabViewHolder(
            LayoutInflater
                .from(parent.context)
                .inflate(viewType, parent, false)
        )
        return tabViewHolder
    }

    override fun getItemCount(): Int {
        return listBean.size
    }

    override fun onBindViewHolder(
        holder: TabViewHolder,
        position: Int
    ) {
        handleClick(holder)
        bindDataToView(
            holder, position, listBean[position],
            position == positionSelected
        )
    }

    private fun handleClick(holder: TabViewHolder) {
        holder.itemView.setOnClickListener {
            val position = holder.adapterPosition
            if (positionSelectedLast != position) {
                positionSelected = position
                notifyItemChanged(positionSelected)
                notifyItemChanged(positionSelectedLast)
                positionSelectedLast = position
            }

            onItemClick(holder, position, listBean[position])
        }
    }

    fun getPositionSelectedLast(): Int {
        return positionSelectedLast
    }

    fun setPositionSelectedLast(positionSelectedLast: Int) {
        this.positionSelectedLast = positionSelectedLast
    }

    fun getPositionSelected(): Int {
        return positionSelected
    }

    fun setPositionSelected(positionSelected: Int) {
        if (positionSelectedLast != positionSelected) {
            this.positionSelected = positionSelected
            notifyItemChanged(positionSelected)
            notifyItemChanged(positionSelectedLast)
            positionSelectedLast = positionSelected
        }
    }

    fun setPositionSelectedNoNotify(positionSelected: Int) {
        this.positionSelected = positionSelected
    }

    fun setPositionSelectedNotifyAll(positionSelected: Int) {
        if (positionSelectedLast != positionSelected) {
            this.positionSelected = positionSelected
            notifyDataSetChanged()
            positionSelectedLast = positionSelected
        }
    }


    override fun getItemViewType(position: Int): Int {
        return getItemLayoutID(position, listBean[position])
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> getAdapter(): W {
        return this as W
    }

    override fun getListBean(): MutableList<T> {
        return listBean
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> set(index: Int, bean: T): W {
        setNoNotify<TabAdapter<T>>(index, bean)
        notifyItemChanged(index)
        return this as W
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> setNoNotify(index: Int, bean: T): W {
        listBean[index] = bean
        return this as W
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> clear(): W {
        listBean.clear()
        notifyDataSetChanged()
        return this as W
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> clearNoNotify(): W {
        listBean.clear()
        return this as W
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> clearAdd(beans: List<T>?): W {
        clearAddNoNotify<TabAdapter<T>>(beans)
        notifyDataSetChanged()
        return this as W
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> clearAdd(bean: T): W {
        clearNoNotify<TabAdapter<T>>()
        add<TabAdapter<T>>(bean)
        notifyDataSetChanged()
        return this as W
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> clearAddNoNotify(bean: T): W {
        clearAdd<TabAdapter<T>>(bean)
        return this as W
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> clearAddNoNotify(beans: List<T>?): W {
        listBean.clear()
        if (beans != null) {
            listBean.addAll(beans)
        }
        return this as W
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> addToTop(beans: List<T>?): W {
        addToTopNoNotify<TabAdapter<T>>(beans)


        //没有刷新的作用
//        notifyItemRangeInserted(0, beans.size());
        notifyDataSetChanged()
        return this as W
    }

    /**
     * 添加一条数据item到position 0,并且notify
     */
    override fun <W : ITabAdapter<T, TabViewHolder>> addToTop(bean: T): W {
        addToTopNoNotify<TabAdapter<T>>(bean)
        notifyItemInserted(0)
        return this as W
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> addToTopNoNotify(beans: List<T>?): W {
        if (beans != null) {
            listBean.addAll(0, beans)
        }
        return this as W
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> addToTopNoNotify(bean: T): W {
        listBean.add(0, bean)
        return this as W
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> add(beans: List<T>?): W {
        addNoNotify<TabAdapter<T>>(beans)
        notifyItemRangeInserted(listBean.size - beans!!.size, beans.size)
        return this as W
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> add(bean: T): W {
        addNoNotify<TabAdapter<T>>(bean)
        notifyItemInserted(listBean.size - 1)
        return this as W
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> add(position: Int, bean: T): W {
        addNoNotify<TabAdapter<T>>(position, bean)
        notifyItemInserted(position)
        return this as W
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> addNoNotify(beans: List<T>?): W {
        if (beans != null) {
            listBean.addAll(beans)
        }

        return this as W
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> addNoNotify(bean: T): W {
        listBean.add(bean)
        return this as W
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> addNoNotify(position: Int, bean: T): W {
        listBean.add(position, bean)
        return this as W
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> remove(position: Int): W {
        removeNoNotify<TabAdapter<T>>(position)

        /**
         * onBindViewHolder回调的position永远是最后一个可见的item的position,
         * 比如一次最多只能看到5个item,只要执行了notifyItemRemoved(position)，
         * onBindViewHolder回调的position永远是4
         */
        notifyItemRemoved(position)
        return this as W
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> removeNoNotify(position: Int): W {
        listBean.removeAt(position)
        return this as W
    }

    override fun <W : ITabAdapter<T, TabViewHolder>> setListBean(listBean: MutableList<T>): W {
        this.listBean = listBean
        notifyDataSetChanged()
        return this as W
    }

    abstract override fun onItemClick(holder: TabViewHolder, position: Int, bean: T)

    abstract override fun getItemLayoutID(position: Int, bean: T): Int

    abstract override fun bindDataToView(
        holder: TabViewHolder,
        position: Int,
        bean: T,
        isSelected: Boolean
    )
}