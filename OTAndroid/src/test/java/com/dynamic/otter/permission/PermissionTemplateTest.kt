package com.dynamic.otter.permission

import com.dynamic.otter.template.json.TemplateJsonParser
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class PermissionTemplateTest {
    @Test
    fun parsesPermissionPages() {
        val root = File("../Demo/src/main/assets")
        listOf(
            "templates/permission/permission.json",
            "templates/market/mine.json",
            "templates/market/home.json",
            "templates/market/shop.json",
            "templates/market/result.json"
        ).forEach { path ->
            val file = File(root, path)
            assertTrue(file.path, file.isFile)
            TemplateJsonParser.parse(file.readText())
        }
    }
}
