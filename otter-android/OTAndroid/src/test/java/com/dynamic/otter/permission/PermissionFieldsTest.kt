package com.dynamic.otter.permission

import com.alibaba.fastjson.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PermissionFieldsTest {
    @Test
    fun writesCameraStatusOntoPageData() {
        val data = JSONObject()
        PermissionFields.write(
            data,
            PermissionJudge.single(
                PermissionCapability.CAMERA,
                granted = false,
                asked = true,
                shouldShowRationale = false
            )
        )

        assertEquals(PermissionStatus.PERMANENTLY_DENIED, data.getString("cameraStatus"))
        assertEquals("已关闭，要到系统设置里打开", data.getString("cameraStatusText"))
        assertTrue(data.getBooleanValue("cameraShowSettings"))
    }

    @Test
    fun photoGrantStoresTheSelectedUri() {
        val data = JSONObject()
        data["avatar"] = "res:ic_ava_c"
        PermissionFields.write(
            data,
            PermissionJudge.grantedPhoto("content://media/picker/1")
        )

        assertEquals("content://media/picker/1", data.getString("photoSrc"))
        assertEquals("content://media/picker/1", data.getString("avatar"))
        assertTrue(data.getBooleanValue("photoVisible"))
    }

    @Test
    fun laterCheckKeepsTheSelectedPhoto() {
        val data = JSONObject()
        data["avatar"] = "content://media/picker/1"
        val kept = PermissionFields.preservingPhoto(data, PermissionJudge.photos(asked = true))

        assertEquals(PermissionStatus.GRANTED, kept.status)
        assertEquals("content://media/picker/1", kept.detail)
    }

    @Test
    fun resourceAvatarIsNotTreatedAsAPickedPhoto() {
        val data = JSONObject()
        data["avatar"] = "res:ic_ava_c"
        val result = PermissionFields.preservingPhoto(data, PermissionJudge.photos(asked = false))

        assertEquals(PermissionStatus.DENIED, result.status)
        assertFalse(data.containsKey("photoSrc"))
    }

    @Test
    fun unknownCapabilityDoesNotWrite() {
        val data = JSONObject()
        PermissionFields.write(data, PermissionJudge.unsupported("sms"))

        assertNull(data.getString("smsStatus"))
        assertTrue(data.isEmpty())
    }
}
