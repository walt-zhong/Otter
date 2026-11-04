package com.dynamic.otter.render.view.components.tabpager

interface ITabAdapter<T, V : IViewHolder> {
    fun <W : ITabAdapter<T, V>> getAdapter(): W
    fun getListBean(): MutableList<T>
    fun bindDataToView(holder: V, position: Int, bean: T, isSelected: Boolean)
    fun getItemLayoutID(position: Int, bean: T): Int
    fun onItemClick(holder: V, position: Int, bean: T)

    fun <W : ITabAdapter<T, V>> setListBean(listBean: MutableList<T>): W

    /**
     * 删除相应position的数据Item
     */
    fun <W : ITabAdapter<T, V>> removeNoNotify(position: Int): W

    /**
     * 删除相应position的数据Item ,并且notify,
     */
    fun <W : ITabAdapter<T, V>> remove(position: Int): W

    /**
     * 添加一条数据item
     */
    fun <W : ITabAdapter<T, V>> addNoNotify(position: Int, bean: T): W

    /**
     * 添加一条数据item,并且notify
     */
    fun <W : ITabAdapter<T, V>> add(position: Int, bean: T): W


    /**
     * 添加一条数据item
     */
    fun <W : ITabAdapter<T, V>> addNoNotify(bean: T): W

    /**
     * 添加一条数据item,并且notify
     */
    fun <W : ITabAdapter<T, V>> add(bean: T): W

    /**
     * 添加一条数据item到position 0
     */
    fun <W : ITabAdapter<T, V>> addToTopNoNotify(bean: T): W

    /**
     * 添加一条数据item到position 0,并且notify
     */
    fun <W : ITabAdapter<T, V>> addToTop(bean: T): W

    /**
     * 添加List
     */
    fun <W : ITabAdapter<T, V>> addNoNotify(beans: List<T>?): W

    /**
     * 添加List,并且notify
     */
    fun <W : ITabAdapter<T, V>> add(beans: List<T>?): W


    /**
     * 先清空后添加List
     */
    fun <W : ITabAdapter<T, V>> clearAddNoNotify(beans: List<T>?): W


    /**
     * 先清空后添加
     */
    fun <W : ITabAdapter<T, V>> clearAddNoNotify(bean: T): W

    /**
     * 先清空后添加,并且notify
     */
    fun <W : ITabAdapter<T, V>> clearAdd(bean: T): W

    /**
     * 先清空后添加List,并且notify
     */
    fun <W : ITabAdapter<T, V>> clearAdd(beans: List<T>?): W

    /**
     * 添加List到position 0
     */
    fun <W : ITabAdapter<T, V>> addToTopNoNotify(beans: List<T>?): W

    /**
     * 添加List到position 0,并且notify
     */
    fun <W : ITabAdapter<T, V>> addToTop(beans: List<T>?): W

    /**
     * 清空list
     */
    fun <W : ITabAdapter<T, V>> clearNoNotify(): W

    /**
     * 清空list
     */
    fun <W : ITabAdapter<T, V>> clear(): W


    fun <W : ITabAdapter<T, V>> setNoNotify(index: Int, bean: T): W

    fun <W : ITabAdapter<T, V>> set(index: Int, bean: T): W
}