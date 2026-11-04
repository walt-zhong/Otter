package com.dynamic.otter.utils

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AssetsUtilsTest {
    @Test
    fun keepsTemplatePathsInsideTheAssetRoot() {
        assertEquals("templates/home-demo/home.json", AssetsUtils.containedAssetPath("templates/home-demo/home.json"))
        assertNull(AssetsUtils.containedAssetPath("../secrets.json"))
        assertNull(AssetsUtils.containedAssetPath("templates/../../secrets.json"))
        assertNull(AssetsUtils.containedAssetPath("/etc/passwd"))
        assertNull(AssetsUtils.containedAssetPath("templates\\..\\secrets.json"))
        assertNull(AssetsUtils.containedAssetPath("templates/\u0000.json"))
    }

    @Test
    fun readsAFileInsideTheGivenRoot() {
        val root = java.nio.file.Files.createTempDirectory("otter-read").toFile()
        val nested = java.io.File(root, "templates")
        nested.mkdirs()
        java.io.File(nested, "list.json").writeText("{\"ok\":true}")
        assertEquals("{\"ok\":true}", AssetsUtils.readRelative(root, "templates/list.json"))
        try {
            AssetsUtils.readRelative(root, "../list.json")
            throw AssertionError("越界路径应被拒绝")
        } catch (error: IllegalArgumentException) {
            assertEquals("资源路径越界", error.message)
        }
    }
}
