package com.dynamic.otter.demo

import android.util.Base64
import org.bouncycastle.crypto.params.Ed25519PublicKeyParameters
import org.bouncycastle.crypto.signers.Ed25519Signer
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.security.MessageDigest
import java.util.zip.ZipInputStream

internal object BundleVerifier {
    private val names = listOf(
        "routes.json",
        "templates/list.json",
        "templates/detail.json",
        "data/list.json",
        "data/detail.json",
        "manifest.json"
    )
    private val content = names.dropLast(1)
    private const val MAX_FILE = 256 * 1024
    private const val MAX_ZIP = 1024 * 1024

    fun open(raw: ByteArray, publicKey: ByteArray): Map<String, ByteArray> {
        if (publicKey.size != 32) {
            error("公钥无效")
        }
        if (raw.size > MAX_ZIP) {
            error("包太大")
        }
        val modes = unixModes(raw)
        val files = readEntries(raw)
        if (files.keys != names.toSet()) {
            error("包里的文件不符合约定")
        }
        var sum = 0
        for (name in names) {
            val body = files.getValue(name)
            if (body.size > MAX_FILE) {
                error("文件太大")
            }
            sum += body.size
            val mode = modes[name]
            if (mode != null && mode and 0x49 != 0) {
                error("包内文件不能执行")
            }
        }
        if (sum > MAX_ZIP) {
            error("包太大")
        }
        val manifest = JSONObject(files.getValue("manifest.json").toString(Charsets.UTF_8))
        val expected = arrayOf("id", "intent", "sample", "createdAt", "hash", "alg", "signature")
        if (manifest.length() != expected.size || expected.any { !manifest.has(it) }) {
            error("manifest 无效")
        }
        if (manifest.getString("alg") != "ed25519") {
            error("manifest 无效")
        }
        val digest = digest(files)
        val hex = digest.joinToString("") { "%02x".format(it) }
        if (hex != manifest.getString("hash")) {
            error("摘要不一致")
        }
        val signature = Base64.decode(manifest.getString("signature"), Base64.DEFAULT)
        if (!verify(publicKey, digest, signature)) {
            error("签名无效")
        }
        return files
    }

    private fun verify(publicKey: ByteArray, digest: ByteArray, signature: ByteArray): Boolean {
        val signer = Ed25519Signer()
        signer.init(false, Ed25519PublicKeyParameters(publicKey, 0))
        signer.update(digest, 0, digest.size)
        return signer.verifySignature(signature)
    }

    private fun digest(files: Map<String, ByteArray>): ByteArray {
        val md = MessageDigest.getInstance("SHA-256")
        for (name in content) {
            val body = files.getValue(name)
            md.update(name.toByteArray(Charsets.UTF_8))
            md.update(0x0A)
            md.update(body.size.toString().toByteArray(Charsets.US_ASCII))
            md.update(0x0A)
            md.update(body)
        }
        return md.digest()
    }

    private fun readEntries(raw: ByteArray): Map<String, ByteArray> {
        val out = linkedMapOf<String, ByteArray>()
        ZipInputStream(ByteArrayInputStream(raw)).use { zip ->
            while (true) {
                val entry = zip.nextEntry ?: break
                if (entry.isDirectory || !names.contains(entry.name) || entry.method != 0) {
                    error("包里的文件不符合约定")
                }
                if (out.containsKey(entry.name)) {
                    error("包里的文件不符合约定")
                }
                val body = zip.readBytes()
                if (body.size > MAX_FILE) {
                    error("文件太大")
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
            if (offset + 46 > raw.size || u32(raw, offset) != 0x02014b50) {
                error("包里的文件不符合约定")
            }
            val madeBy = u16(raw, offset + 4)
            val method = u16(raw, offset + 10)
            val nameLen = u16(raw, offset + 28)
            val extraLen = u16(raw, offset + 30)
            val commentLen = u16(raw, offset + 32)
            val external = u32(raw, offset + 38)
            val nameStart = offset + 46
            val name = raw.copyOfRange(nameStart, nameStart + nameLen).toString(Charsets.UTF_8)
            if (method != 0) {
                error("包里的文件不符合约定")
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
        error("包里的文件不符合约定")
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
