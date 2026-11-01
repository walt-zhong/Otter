package com.dynamic.otter.permission

import com.alibaba.fastjson.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PermissionJudgeTest {
    @Test
    fun firstLookIsDeniedAndCanAskAgain() {
        val result = PermissionJudge.single(
            PermissionCapability.CAMERA,
            granted = false,
            asked = false,
            shouldShowRationale = false
        )

        assertEquals(PermissionStatus.DENIED, result.status)
        assertTrue(result.canAskAgain)
        assertFalse(result.showSettings)
        assertEquals("还没问过", result.statusText())
    }

    @Test
    fun denyWithRationaleCanAskAgain() {
        val result = PermissionJudge.single(
            PermissionCapability.MICROPHONE,
            granted = false,
            asked = true,
            shouldShowRationale = true
        )

        assertEquals(PermissionStatus.DENIED, result.status)
        assertTrue(result.canAskAgain)
        assertEquals("未允许", result.statusText())
    }

    @Test
    fun secondDenyWithoutRationaleIsPermanent() {
        val result = PermissionJudge.single(
            PermissionCapability.CAMERA,
            granted = false,
            asked = true,
            shouldShowRationale = false
        )

        assertEquals(PermissionStatus.PERMANENTLY_DENIED, result.status)
        assertFalse(result.canAskAgain)
        assertTrue(result.showSettings)
        assertEquals("已关闭，要到系统设置里打开", result.statusText())
    }

    @Test
    fun coarseOnlyLocationIsLimited() {
        val result = PermissionJudge.location(
            fineGranted = false,
            coarseGranted = true,
            asked = true,
            fineShouldShow = true,
            coarseShouldShow = false
        )

        assertEquals(PermissionStatus.LIMITED, result.status)
        assertEquals("approximate", result.detail)
        assertTrue(result.canAskAgain)
        assertFalse(result.showSettings)
        assertEquals("只给了大致位置", result.statusText())
    }

    @Test
    fun fineLocationIsPrecise() {
        val result = PermissionJudge.location(
            fineGranted = true,
            coarseGranted = true,
            asked = true,
            fineShouldShow = false,
            coarseShouldShow = false
        )

        assertEquals(PermissionStatus.GRANTED, result.status)
        assertEquals("已允许，精确位置", result.statusText())
    }

    @Test
    fun notificationsBeforeRuntimeAreGranted() {
        val result = PermissionJudge.notifications(
            requiresRuntime = false,
            granted = false,
            asked = false,
            shouldShowRationale = false
        )

        assertEquals(PermissionStatus.GRANTED, result.status)
        assertEquals("已允许", result.statusText())
    }

    @Test
    fun unknownCapabilityIsUnsupported() {
        val result = PermissionJudge.unsupported("sms")

        assertEquals(PermissionStatus.UNSUPPORTED, result.status)
        assertEquals("当前版本没有这项", result.statusText())
        assertFalse(result.canAskAgain)
    }
}
