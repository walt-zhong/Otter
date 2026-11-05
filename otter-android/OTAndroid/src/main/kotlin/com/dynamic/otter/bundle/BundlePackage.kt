package com.dynamic.otter.bundle

import com.alibaba.fastjson.JSON
import com.alibaba.fastjson.JSONException
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.nav.PageRouteParser
import com.dynamic.otter.template.json.TemplateJsonParser
import com.dynamic.otter.template.json.TemplateParseException
import org.bouncycastle.crypto.params.Ed25519PublicKeyParameters
import org.bouncycastle.crypto.signers.Ed25519Signer
import java.io.ByteArrayInputStream
import java.security.MessageDigest
import java.util.Base64
import java.util.zip.ZipException
import java.util.zip.ZipInputStream

internal data class OpenedBundle(
    val id: String,
    val intent: String,
    val sample: Boolean,
    val files: Map<String, ByteArray>
)

internal object BundlePackage {
    private val names = listOf(
        "routes.json",
        "templates/list.json",
        "templates/detail.json",
        "data/list.json",
        "data/detail.json",
        "manifest.json"
    )
    private val content = names.dropLast(1)
    private val manifestKeys = setOf("id", "intent", "sample", "createdAt", "hash", "alg", "signature")
    private val idPattern = Regex("[A-Za-z0-9][A-Za-z0-9._-]{0,80}")
    private const val MAX_FILE = 256 * 1024
    private const val MAX_ZIP = 1024 * 1024

    fun open(raw: ByteArray, publicKey: ByteArray): OpenedBundle {
        if (raw.size > MAX_ZIP) {
            throw BundleException(BundleFailure.TOO_LARGE, "包太大")
        }
        val modes = try {
            unixModes(raw)
        } catch (error: BundleException) {
            throw error
        } catch (error: Exception) {
            throw BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定", error)
        }
        val files = try {
            readEntries(raw)
        } catch (error: BundleException) {
            throw error
        } catch (error: ZipException) {
            throw BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定", error)
        }
        if (files.keys != names.toSet()) {
            throw BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定")
        }
        var sum = 0
        for (name in names) {
            val body = files.getValue(name)
            if (body.size > MAX_FILE) {
                throw BundleException(BundleFailure.TOO_LARGE, "文件太大")
            }
            sum += body.size
            rejectMode(modes[name])
        }
        if (sum > MAX_ZIP) {
            throw BundleException(BundleFailure.TOO_LARGE, "包太大")
        }
        return accept(files, publicKey)
    }

    fun accept(files: Map<String, ByteArray>, publicKey: ByteArray): OpenedBundle {
        if (publicKey.size != 32) {
            throw BundleException(BundleFailure.PUBLIC_KEY, "公钥无效")
        }
        if (files.keys != names.toSet()) {
            throw BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定")
        }
        val manifest = parseManifest(files.getValue("manifest.json"))
        val digest = digest(files)
        val hex = digest.joinToString("") { "%02x".format(it) }
        if (hex != manifest.getString("hash")) {
            throw BundleException(BundleFailure.DIGEST, "摘要不一致")
        }
        val signature = try {
            Base64.getMimeDecoder().decode(manifest.getString("signature"))
        } catch (error: IllegalArgumentException) {
            throw BundleException(BundleFailure.SIGNATURE, "签名无效", error)
        }
        if (signature.size != 64 || !verify(publicKey, digest, signature)) {
            throw BundleException(BundleFailure.SIGNATURE, "签名无效")
        }
        val id = manifest.getString("id")
        if (!idPattern.matches(id)) {
            throw BundleException(BundleFailure.MANIFEST, "manifest 无效")
        }
        acceptContent(files)
        return OpenedBundle(
            id = id,
            intent = manifest.getString("intent"),
            sample = manifest.getBoolean("sample"),
            files = files
        )
    }

    fun digest(files: Map<String, ByteArray>): ByteArray {
        val md = MessageDigest.getInstance("SHA-256")
        for (name in content) {
            val body = files[name] ?: throw BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定")
            md.update(name.toByteArray(Charsets.UTF_8))
            md.update(0x0A)
            md.update(body.size.toString().toByteArray(Charsets.US_ASCII))
            md.update(0x0A)
            md.update(body)
        }
        return md.digest()
    }

    private fun acceptContent(files: Map<String, ByteArray>) {
        val routes = try {
            PageRouteParser.parse(files.getValue("routes.json").toString(Charsets.UTF_8))
        } catch (error: TemplateParseException) {
            throw BundleException(BundleFailure.PARSE, error.message ?: "路由无法解析", error)
        }
        val seenTemplates = mutableSetOf<String>()
        val seenData = mutableSetOf<String>()
        for (page in routes.pages.values) {
            acceptTemplate(files, page.template)
            seenTemplates.add(page.template)
            val data = page.data ?: continue
            acceptData(files, data)
            seenData.add(data)
        }
        for (name in files.keys) {
            if (name.startsWith("templates/") && name !in seenTemplates) {
                acceptTemplate(files, name)
            }
            if (name.startsWith("data/") && name !in seenData) {
                acceptData(files, name)
            }
        }
    }

    private fun acceptTemplate(files: Map<String, ByteArray>, path: String) {
        val body = files[path]
        if (body == null || !path.startsWith("templates/")) {
            throw BundleException(BundleFailure.PARSE, "页面模版不在包内")
        }
        try {
            TemplateJsonParser.parse(body.toString(Charsets.UTF_8))
        } catch (error: TemplateParseException) {
            throw BundleException(BundleFailure.PARSE, error.message ?: "模版无法解析", error)
        }
    }

    private fun acceptData(files: Map<String, ByteArray>, path: String) {
        val body = files[path]
        if (body == null || !path.startsWith("data/")) {
            throw BundleException(BundleFailure.PARSE, "页面数据不在包内")
        }
        val parsed = try {
            JSON.parse(body.toString(Charsets.UTF_8))
        } catch (error: JSONException) {
            throw BundleException(BundleFailure.PARSE, "数据不是合法 JSON", error)
        }
        if (parsed !is JSONObject) {
            throw BundleException(BundleFailure.PARSE, "数据必须是 JSON 对象")
        }
    }

    private fun parseManifest(raw: ByteArray): JSONObject {
        val manifest = try {
            JSON.parseObject(raw.toString(Charsets.UTF_8))
        } catch (error: JSONException) {
            throw BundleException(BundleFailure.MANIFEST, "manifest 无效", error)
        } ?: throw BundleException(BundleFailure.MANIFEST, "manifest 无效")
        if (manifest.keys.toSet() != manifestKeys) {
            throw BundleException(BundleFailure.MANIFEST, "manifest 无效")
        }
        for (key in listOf("id", "intent", "createdAt", "hash", "alg", "signature")) {
            val value = manifest.get(key)
            if (value !is String || value.isEmpty()) {
                throw BundleException(BundleFailure.MANIFEST, "manifest 无效")
            }
        }
        if (manifest.get("sample") !is Boolean) {
            throw BundleException(BundleFailure.MANIFEST, "manifest 无效")
        }
        if (manifest.getString("alg") != "ed25519") {
            throw BundleException(BundleFailure.MANIFEST, "manifest 无效")
        }
        return manifest
    }

    private fun verify(publicKey: ByteArray, digest: ByteArray, signature: ByteArray): Boolean {
        val signer = Ed25519Signer()
        signer.init(false, Ed25519PublicKeyParameters(publicKey, 0))
        signer.update(digest, 0, digest.size)
        return signer.verifySignature(signature)
    }

    private fun rejectMode(mode: Int?) {
        if (mode == null) {
            return
        }
        if (mode and 0x49 != 0 || mode and 0xF000 == 0xA000) {
            throw BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定")
        }
    }

    private fun readEntries(raw: ByteArray): Map<String, ByteArray> {
        val out = linkedMapOf<String, ByteArray>()
        ZipInputStream(ByteArrayInputStream(raw)).use { zip ->
            while (true) {
                val entry = zip.nextEntry ?: break
                if (entry.isDirectory || !names.contains(entry.name) || entry.method != 0) {
                    throw BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定")
                }
                if (out.containsKey(entry.name)) {
                    throw BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定")
                }
                if (entry.size > MAX_FILE) {
                    throw BundleException(BundleFailure.TOO_LARGE, "文件太大")
                }
                val body = zip.readBytes()
                if (body.size > MAX_FILE) {
                    throw BundleException(BundleFailure.TOO_LARGE, "文件太大")
                }
                out[entry.name] = body
            }
        }
        return out
    }

    private fun unixModes(raw: ByteArray): Map<String, Int> {
        val eocd = findEocd(raw)
        val count = u16(raw, eocd + 10)
        var offset = u32(raw, eocd + 16)
        val modes = HashMap<String, Int>(count)
        repeat(count) {
            if (offset < 0 || offset + 46 > raw.size || u32(raw, offset) != 0x02014b50) {
                throw BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定")
            }
            val madeBy = u16(raw, offset + 4)
            val method = u16(raw, offset + 10)
            val nameLen = u16(raw, offset + 28)
            val extraLen = u16(raw, offset + 30)
            val commentLen = u16(raw, offset + 32)
            val external = u32(raw, offset + 38)
            val nameStart = offset + 46
            if (nameStart + nameLen + extraLen + commentLen > raw.size) {
                throw BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定")
            }
            val name = raw.copyOfRange(nameStart, nameStart + nameLen).toString(Charsets.UTF_8)
            if (method != 0) {
                throw BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定")
            }
            if ((madeBy ushr 8) == 3) {
                modes[name] = (external ushr 16) and 0xffff
            }
            offset = nameStart + nameLen + extraLen + commentLen
        }
        return modes
    }

    private fun findEocd(raw: ByteArray): Int {
        val start = maxOf(0, raw.size - 22 - 0xffff)
        for (index in raw.size - 22 downTo start) {
            if (raw[index] == 0x50.toByte() &&
                raw[index + 1] == 0x4b.toByte() &&
                raw[index + 2] == 0x05.toByte() &&
                raw[index + 3] == 0x06.toByte()
            ) {
                return index
            }
        }
        throw BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定")
    }

    private fun u16(raw: ByteArray, offset: Int): Int {
        return (raw[offset].toInt() and 0xff) or ((raw[offset + 1].toInt() and 0xff) shl 8)
    }

    private fun u32(raw: ByteArray, offset: Int): Int {
        return (raw[offset].toInt() and 0xff) or
            ((raw[offset + 1].toInt() and 0xff) shl 8) or
            ((raw[offset + 2].toInt() and 0xff) shl 16) or
            ((raw[offset + 3].toInt() and 0xff) shl 24)
    }
}
