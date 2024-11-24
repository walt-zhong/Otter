package com.dynamic.otter.data

import android.view.View
import com.dynamic.otter.render.node.VDomNode

object ListContainerData {
    // 用于存放列表容器的itemView的虚拟DOM。key为列表容器控件的ID，value为列表容器的itemView的虚拟DOM
    var listItemVNodeMap: MutableMap<String, VDomNode> = mutableMapOf()
    var listItemAndroidViewMap: MutableMap<String, View> = mutableMapOf()
}