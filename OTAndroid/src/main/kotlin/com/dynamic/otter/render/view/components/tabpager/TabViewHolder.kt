package com.dynamic.otter.render.view.components.tabpager

import android.util.SparseArray
import android.view.View
import android.view.View.OnLongClickListener
import android.widget.ImageView
import android.widget.ProgressBar
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView

class TabViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView), IViewHolder {
    private val viewArr: SparseArray<View> = SparseArray()

    override fun <T : View> getView(viewId: Int): T {
        var view = viewArr.get(viewId)
        if (view == null) {
            view = itemView.findViewById(viewId)
            viewArr.put(viewId, view)
        }

        return view as T
    }

    fun putView(viewId: Int, view: View) {
        viewArr.put(viewId, view)
    }

    fun setVisible(resId: Int) {
        getView<View>(resId).visibility = View.VISIBLE
    }

    fun setInVisible(resId: Int) {
        getView<View>(resId).visibility = View.INVISIBLE
    }

    fun setGone(resId: Int) {
        getView<View>(resId).visibility = View.GONE
    }

    private fun nullToString(any: Any?): String {
        return any?.toString() ?: ""
    }

    fun setText(tvId: Int, text: Any?) {
        val textView = getView<TextView>(tvId)
        textView.text = nullToString(text)
    }

    //设置TextView或者EditText的TextColor
    fun setTextColor(tvId: Int, color: Int): TabViewHolder {
        val tv = getView<TextView>(tvId)
        tv.setTextColor(color)
        return this
    }


    //设置ImageView的ImageResource
    fun setImageResource(ivId: Int, resID: Int): TabViewHolder {
        val view = getView<ImageView>(ivId)
        view.setImageResource(resID)
        return this
    }

    //设置进度条进度
    fun setProgress(progressId: Int, progress: Int) {
        val progressBar = getView<ProgressBar>(progressId)
        progressBar.progress = progress
    }

    //设置点击监听
    fun setOnClickListener(resId: Int, onClickListener: View.OnClickListener?) {
        getView<View>(resId).setOnClickListener(onClickListener)
    }

    //设置长按监听
    fun setOnLongClickListener(resId: Int, onLongClickListener: OnLongClickListener?) {
        getView<View>(resId).setOnLongClickListener(onLongClickListener)
    }
}