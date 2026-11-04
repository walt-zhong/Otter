package com.dynamic.otter.render.view.components.tabpager.adapter

import com.dynamic.otter.render.view.components.tabpager.IViewHolder

interface IBaseTabPageAdapter<T,V:IViewHolder> {
    fun bindDataToTab(holder: V, position: Int, bean: T, isSelected: Boolean)

    fun getTabLayoutID(position: Int, bean: T): Int

    fun onTabClick(holder: V, position: Int, bean: T)

    fun onTabScrolled(
        holderCurrent: V, positionCurrent: Int,
        fromLeft2RightCurrent: Boolean, positionOffsetCurrent: Float, holder2: V, position2: Int,
        fromLeft2Right2: Boolean, positionOffset2: Float
    )

    fun <W : IBaseTabPageAdapter<T, V>> setListBean(listBean: MutableList<T>): W

    fun getListBean(): List<T>

    /**
     * 删除相应position的数据Item
     */
    fun <W : IBaseTabPageAdapter<T, V>> removeNoNotify(position: Int): W

    /**
     * 删除相应position的数据Item ,并且notify,
     */
    fun <W : IBaseTabPageAdapter<T, V>> remove(position: Int): W

    /**
     * 添加一条数据item
     */
    fun <W : IBaseTabPageAdapter<T, V>> addNoNotify(position: Int, bean: T): W

    /**
     * 添加一条数据item,并且notify
     */
    fun <W : IBaseTabPageAdapter<T, V>> add(position: Int, bean: T): W

    /**
     * 添加一条数据item
     */
    fun <W : IBaseTabPageAdapter<T, V>> addNoNotify(bean: T): W

    /**
     * 添加一条数据item,并且notify
     */
    fun <W : IBaseTabPageAdapter<T, V>> add(bean: T): W

    /**
     * 添加一条数据item到position 0
     */
    fun <W : IBaseTabPageAdapter<T, V>> addToTopNoNotify(bean: T): W

    /**
     * 添加一条数据item到position 0,并且notify
     */
    fun <W : IBaseTabPageAdapter<T, V>> addToTop(bean: T): W

    /**
     * 添加List
     */
    fun <W : IBaseTabPageAdapter<T, V>> addNoNotify(beans: List<T>): W

    /**
     * 添加List,并且notify
     */
    fun <W : IBaseTabPageAdapter<T, V>> add(beans: MutableList<T>): W

    /**
     * 先清空后添加List
     */
    fun <W : IBaseTabPageAdapter<T, V>?> clearAddNoNotify(beans: List<T>?): W


    /**
     * 先清空后添加
     */
    fun <W : IBaseTabPageAdapter<T, V>?> clearAddNoNotify(bean: T): W

    /**
     * 先清空后添加,并且notify
     */
    fun <W : IBaseTabPageAdapter<T, V>?> clearAdd(bean: T): W

    /**
     * 先清空后添加List,并且notify
     */
    fun <W : IBaseTabPageAdapter<T, V>?> clearAdd(beans: List<T>?): W

    /**
     * 添加List到position 0
     */
    fun <W : IBaseTabPageAdapter<T, V>?> addToTopNoNotify(beans: List<T>?): W

    /**
     * 添加List到position 0,并且notify
     */
    fun <W : IBaseTabPageAdapter<T, V>?> addToTop(beans: List<T>?): W

    /**
     * 清空list
     */
    fun <W : IBaseTabPageAdapter<T, V>?> clearNoNotify(): W

    /**
     * 清空list
     */
    fun <W : IBaseTabPageAdapter<T, V>?> clear(): W


    fun <W : IBaseTabPageAdapter<T, V>?> setNoNotify(index: Int, bean: T): W

    fun <W : IBaseTabPageAdapter<T, V>?> set(index: Int, bean: T): W
}