package com.dynamic.otter.render.view.attr

import com.dynamic.otter.data.TemplateKey
import org.w3c.dom.NamedNodeMap

open class ContainerAttr: ViewAttr() {
     var justifyContent:String? = null
     var alignItems:String? = null

     override fun parseAttrs(attrsMap: NamedNodeMap): ViewAttr {
          super.parseAttrs(attrsMap)
          for (i in 0 until attrsMap.length){
               val attrName = attrsMap.item(i).nodeName
               val attrValue = attrsMap.item(i).nodeValue
               when (attrName) {
                    TemplateKey.FLEXBOX_ATTR_JUSTIFY_CONTENT->{
                         justifyContent = attrValue
                    }
                    TemplateKey.FLEXBOX_ATTR_ALIGN_ITEMS->{
                         alignItems = attrValue
                    }
               }
          }
          return this
     }
}