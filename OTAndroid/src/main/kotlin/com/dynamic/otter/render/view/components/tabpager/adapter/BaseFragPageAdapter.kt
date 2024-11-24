package com.dynamic.otter.render.view.components.tabpager.adapter

import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentManager
import androidx.lifecycle.Lifecycle
import com.dynamic.otter.render.view.components.tabpager.IViewHolder

abstract class BaseFragPageAdapter<T, V : IViewHolder>
    : FragStatePageAdapter, IBaseTabPageAdapter<T, V> {

    private var listBean: MutableList<T> = mutableListOf()

    constructor(fragmentActivity: FragmentActivity) : super(fragmentActivity)

    constructor(fragment: Fragment) : super(fragment)

    constructor(fragmentManager: FragmentManager, lifecycle: Lifecycle) : super(
        fragmentManager,
        lifecycle
    )

    override fun createFragment(position: Int): Fragment {
        return createFragment(listBean[position],position)
    }

    override fun getItemCount(): Int {
        return listBean.size
    }

    abstract fun createFragment(bean: T, position: Int): Fragment

    override fun onTabScrolled(
        holderCurrent: V,
        positionCurrent: Int,
        fromLeft2RightCurrent: Boolean,
        positionOffsetCurrent: Float,
        holder2: V,
        position2: Int,
        fromLeft2Right2: Boolean,
        positionOffset2: Float
    ) {
    }

    override fun onTabClick(holder: V, position: Int, bean: T) {
    }


    override fun <W : IBaseTabPageAdapter<T, V>> setListBean(listBean: MutableList<T>): W {
        this.listBean = listBean

        notifyDataSetChanged()
        return this as W
    }

    override fun getListBean(): List<T> {
        return listBean
    }

    override fun <W : IBaseTabPageAdapter<T, V>> removeNoNotify(position: Int): W {
        listBean.removeAt(position)
        return this as W
    }

    override fun <W : IBaseTabPageAdapter<T, V>> remove(position: Int): W {
        removeNoNotify<IBaseTabPageAdapter<T, V>>(position)

        /**
         * onBindViewHolder回调的position永远是最后一个可见的item的position,
         * 比如一次最多只能看到5个item,只要执行了notifyItemRemoved(position)，
         * onBindViewHolder回调的position永远是4
         */
        notifyItemRemoved(position)
        return this as W
    }

    override fun <W : IBaseTabPageAdapter<T, V>> add(bean: T): W {
        addNoNotify<BaseFragPageAdapter<T,V>>(bean)
        notifyItemInserted(listBean.size - 1)
        return this as W
    }

    override fun <W : IBaseTabPageAdapter<T, V>> add(position: Int, bean: T): W {
        addNoNotify<BaseFragPageAdapter<T,V>>(position, bean)
        return this as W

    }

    override fun <W : IBaseTabPageAdapter<T, V>> addNoNotify(bean: T): W {
        listBean.add(bean)
        return this as W
    }

    override fun <W : IBaseTabPageAdapter<T, V>> addNoNotify(beans: List<T>): W {
        listBean.addAll(beans)

        return this as W
    }

    override fun <W : IBaseTabPageAdapter<T, V>> addNoNotify(position: Int, bean: T): W {
        listBean.add(position, bean)
        return this as W
    }

    override fun <W : IBaseTabPageAdapter<T, V>> addToTopNoNotify(bean: T): W {
        listBean.add(0,bean)
        return this as W
    }

    override fun <W : IBaseTabPageAdapter<T, V>> addToTop(bean: T): W {
        addToTopNoNotify<BaseFragPageAdapter<T,V>>(bean)
        notifyItemInserted(0)
        return this as W
    }

    override fun <W : IBaseTabPageAdapter<T, V>> add(beans: MutableList<T>): W {
        addNoNotify<BaseFragPageAdapter<T,V>>(beans)
        notifyItemRangeInserted(listBean.size-beans.size,beans.size)
        return this@BaseFragPageAdapter as W
    }

    /**
     * 先清空后添加List
     */
    override fun <W : IBaseTabPageAdapter<T, V>?> clearAddNoNotify(beans: List<T>?): W {
        listBean.clear()
        if (beans != null) {
            listBean.addAll(beans)
        }
        return this as W
    }


    /**
     * 先清空后添加
     */
    override fun <W : IBaseTabPageAdapter<T, V>?> clearAddNoNotify(bean: T): W {
        clearAdd<IBaseTabPageAdapter<T, V>>(bean)
        return this as W
    }

    /**
     * 先清空后添加,并且notify
     */
    override fun <W : IBaseTabPageAdapter<T, V>?> clearAdd(bean: T): W {
        clearNoNotify<IBaseTabPageAdapter<T, V>>()
        add<IBaseTabPageAdapter<T, V>>(bean)
        notifyDataSetChanged()
        return this as W
    }

    /**
     * 先清空后添加List,并且notify
     */
    override fun <W : IBaseTabPageAdapter<T, V>?> clearAdd(beans: List<T>?): W {
        clearAddNoNotify<IBaseTabPageAdapter<T, V>>(beans)
        notifyDataSetChanged()
        return this as W
    }

    /**
     * 添加List到position 0
     */
    override fun <W : IBaseTabPageAdapter<T, V>?> addToTopNoNotify(beans: List<T>?): W {
        if (beans != null) {
            listBean.addAll(0, beans)
        }
        return this as W
    }

    /**
     * 添加List到position 0,并且notify
     */
    override fun <W : IBaseTabPageAdapter<T, V>?> addToTop(beans: List<T>?): W {
        addToTopNoNotify<IBaseTabPageAdapter<T, V>>(beans)
        //没有刷新的作用
//        notifyItemRangeInserted(0, beans.size());
        notifyDataSetChanged()
        return this as W
    }

    /**
     * 清空list
     */
    override fun <W : IBaseTabPageAdapter<T, V>?> clearNoNotify(): W {
        listBean.clear()
        return this as W
    }

    /**
     * 清空list
     */
    override fun <W : IBaseTabPageAdapter<T, V>?> clear(): W {
        listBean.clear()
        notifyDataSetChanged()
        return this as W
    }

    override fun <W : IBaseTabPageAdapter<T, V>?> setNoNotify(index: Int, bean: T): W {
        listBean.set(index, bean)
        return this as W
    }

    override fun <W : IBaseTabPageAdapter<T, V>?> set(index: Int, bean: T): W {
        setNoNotify<IBaseTabPageAdapter<T, V>>(index, bean)
        notifyItemChanged(index)
        return this as W
    }
}