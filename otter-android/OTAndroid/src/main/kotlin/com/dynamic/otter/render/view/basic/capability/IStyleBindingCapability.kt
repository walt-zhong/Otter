package com.dynamic.otter.render.view.basic.capability

import com.dynamic.otter.render.view.attr.ViewAttr

interface IStyleBindingCapability {
    fun onBindStyle(attr: ViewAttr, attrData:Any? = null)
}