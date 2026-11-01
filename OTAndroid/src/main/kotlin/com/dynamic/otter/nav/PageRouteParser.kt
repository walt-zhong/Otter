package com.dynamic.otter.nav

import com.alibaba.fastjson.JSON
import com.alibaba.fastjson.JSONException
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.template.json.TemplateParseException

data class PageRoute(val template: String, val data: String?)

data class PageRouteTable(val start: String, val pages: Map<String, PageRoute>)

object PageRouteParser {
    private val namePattern = Regex("[A-Za-z_][A-Za-z0-9_]*")

    fun parse(json: String): PageRouteTable {
        val root = try {
            JSON.parseObject(json)
        } catch (error: JSONException) {
            throw TemplateParseException("路由不是合法 JSON：${error.message}")
        } ?: throw TemplateParseException("路由必须是 JSON 对象")

        requireKeys(root, "$", allowed = setOf("start", "pages"), required = setOf("start", "pages"))
        val start = requireString(root.get("start"), "$.start")
        if (!namePattern.matches(start)) {
            throw TemplateParseException("$.start「$start」必须是字母或下划线开头的标识符")
        }
        val pagesObject = requireObject(root.get("pages"), "$.pages")
        if (pagesObject.isEmpty()) {
            throw TemplateParseException("$.pages 不能是空对象")
        }
        val pages = linkedMapOf<String, PageRoute>()
        for (name in pagesObject.keys) {
            if (!namePattern.matches(name)) {
                throw TemplateParseException("$.pages 的页面名「$name」必须是字母或下划线开头的标识符")
            }
            val page = requireObject(pagesObject.get(name), "$.pages.$name")
            requireKeys(
                page,
                "$.pages.$name",
                allowed = setOf("template", "data"),
                required = setOf("template")
            )
            val template = requireString(page.get("template"), "$.pages.$name.template")
            if (template.isEmpty()) {
                throw TemplateParseException("$.pages.$name.template 不能是空字符串")
            }
            val data = if (page.containsKey("data")) {
                val dataPath = requireString(page.get("data"), "$.pages.$name.data")
                if (dataPath.isEmpty()) {
                    throw TemplateParseException("$.pages.$name.data 不能是空字符串")
                }
                dataPath
            } else {
                null
            }
            pages[name] = PageRoute(template, data)
        }
        if (start !in pages) {
            throw TemplateParseException("$.start 引用了不存在的页面 $start")
        }
        return PageRouteTable(start, pages)
    }

    private fun requireObject(value: Any?, path: String): JSONObject {
        return value as? JSONObject ?: throw TemplateParseException("$path 必须是对象")
    }

    private fun requireString(value: Any?, path: String): String {
        return value as? String ?: throw TemplateParseException("$path 必须是字符串")
    }

    private fun requireKeys(
        node: JSONObject,
        path: String,
        allowed: Set<String>,
        required: Set<String>
    ) {
        node.keys.forEach { key ->
            if (key !in allowed) {
                throw TemplateParseException("$path.$key 不是这里能写的字段")
            }
        }
        required.forEach { key ->
            if (!node.containsKey(key)) {
                throw TemplateParseException("$path 缺少 $key")
            }
        }
    }
}
