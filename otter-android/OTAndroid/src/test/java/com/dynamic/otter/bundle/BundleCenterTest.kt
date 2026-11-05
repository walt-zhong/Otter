package com.dynamic.otter.bundle

import org.bouncycastle.crypto.generators.Ed25519KeyPairGenerator
import org.bouncycastle.crypto.params.Ed25519KeyGenerationParameters
import org.bouncycastle.crypto.params.Ed25519PrivateKeyParameters
import org.bouncycastle.crypto.params.Ed25519PublicKeyParameters
import org.bouncycastle.crypto.signers.Ed25519Signer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.file.Files
import java.security.SecureRandom
import java.util.Base64
import java.util.zip.CRC32
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class BundleCenterTest {
    private lateinit var cache: File
    private lateinit var publicKey: ByteArray
    private lateinit var privateKey: ByteArray

    @Before
    fun setUp() {
        BundleCenter.resetSnapshot()
        cache = Files.createTempDirectory("otter-bundle").toFile()
        val generator = Ed25519KeyPairGenerator()
        generator.init(Ed25519KeyGenerationParameters(SecureRandom()))
        val pair = generator.generateKeyPair()
        publicKey = (pair.public as Ed25519PublicKeyParameters).encoded
        privateKey = (pair.private as Ed25519PrivateKeyParameters).encoded
    }

    @Test
    fun installsAVerifiedBundleAndReadsItBack() {
        val installed = BundleCenter.install(cache, "shopping", publicKey, pack("bundleA"))
        assertEquals("bundleA", installed.id)
        assertEquals(BundleOrigin.DOWNLOAD, installed.origin)
        assertFalse(installed.fellBack)
        assertNull(installed.failure)
        assertEquals("shopping.browse", installed.intent)
        assertTrue(installed.sample)
        assertEquals("{}", File(installed.root, "data/list.json").readText())

        val again = BundleCenter.current(cache, "shopping", publicKey)
        assertEquals(installed.root.canonicalFile, again?.root?.canonicalFile)
        assertEquals(BundleOrigin.CACHE, again?.origin)
        val snapshot = BundleCenter.snapshot()
        assertEquals(1, snapshot.freshInstalls)
        assertEquals(1.0, snapshot.usableRate, 0.0)
        assertEquals(0.0, snapshot.downloadSuccessRate, 0.0)
    }

    @Test
    fun keepsTheLastVerifiedBundleWhenTheNewZipFails() {
        val first = BundleCenter.install(cache, "shopping", publicKey, pack("bundleA"))
        val broken = pack("bundleB", template = """{"layout":{"type":"nope"}}""")
        val fallback = BundleCenter.install(cache, "shopping", publicKey, broken)
        assertEquals("bundleA", fallback.id)
        assertEquals(BundleOrigin.CACHE, fallback.origin)
        assertTrue(fallback.fellBack)
        assertEquals(BundleFailure.PARSE, fallback.failure)
        assertEquals(first.root.canonicalFile, fallback.root.canonicalFile)
        assertFalse(File(cache, "otter-bundles/shopping/bundleB").exists())

        try {
            BundleCenter.install(cache, "shopping", publicKey, broken, BundleFallback.NONE)
            throw AssertionError("验签或解析失败应抛错")
        } catch (error: BundleException) {
            assertEquals(BundleFailure.PARSE, error.failure)
        }
        assertEquals("bundleA", BundleCenter.current(cache, "shopping", publicKey)?.id)
    }

    @Test
    fun countsDownloadSuccessSeparatelyFromVerification() {
        BundleCenter.install(cache, "shopping", publicKey, pack("bundleA"))
        var fetches = 0
        val ready = BundleCenter.load(cache, "shopping", publicKey) {
            fetches += 1
            BundleDownload("missing", ByteArray(0))
        }
        assertEquals(1, fetches)
        assertEquals("bundleA", ready.id)
        assertTrue(ready.fellBack)
        assertEquals(BundleFailure.LAYOUT, ready.failure)

        val fresh = BundleCenter.load(cache, "shopping", publicKey) {
            fetches += 1
            val zip = pack("bundleC")
            BundleDownload("bundleC", zip, "shopping.browse", true)
        }
        assertEquals("bundleC", fresh.id)
        assertEquals(BundleOrigin.DOWNLOAD, fresh.origin)

        val stats = BundleCenter.snapshot()
        assertEquals(2, stats.fetchAttempts)
        assertEquals(2, stats.fetchSuccess)
        assertEquals(1.0, stats.downloadSuccessRate, 0.0)
        assertEquals(1, stats.cacheFallbacks)
        assertEquals(2, stats.freshInstalls)
        assertEquals(1.0, stats.usableRate, 0.0)
        assertEquals(1, stats.failures[BundleFailure.LAYOUT])
    }

    @Test
    fun networkFailureFallsBackAndLowersTheDownloadRate() {
        BundleCenter.install(cache, "shopping", publicKey, pack("bundleA"))
        BundleCenter.resetSnapshot()
        val ready = BundleCenter.load(cache, "shopping", publicKey) {
            throw IllegalStateException("请求失败")
        }
        assertTrue(ready.fellBack)
        assertEquals(BundleFailure.NETWORK, ready.failure)
        val stats = BundleCenter.snapshot()
        assertEquals(0.0, stats.downloadSuccessRate, 0.0)
        assertEquals(1.0, stats.usableRate, 0.0)
        assertEquals(1, stats.failures[BundleFailure.NETWORK])
    }

    @Test
    fun doesNotFetchWhenThePublicKeyIsInvalid() {
        var called = false
        try {
            BundleCenter.load(cache, "shopping", ByteArray(16)) {
                called = true
                BundleDownload("bundleA", pack("bundleA"))
            }
            throw AssertionError("公钥长度不对应抛错")
        } catch (error: BundleException) {
            assertEquals(BundleFailure.PUBLIC_KEY, error.failure)
        }
        assertFalse(called)
        assertEquals(0, BundleCenter.snapshot().fetchAttempts)
    }

    @Test
    fun dropsATamperedCacheAndKeepsAPackageSignedByAnotherKey() {
        val installed = BundleCenter.install(cache, "shopping", publicKey, pack("bundleA"))
        val list = File(installed.root, "templates/list.json")
        list.writeText("""{"layout":{"type":"column","layout":{"width":"fill","height":"fill"},"tampered":true}}""")
        assertNull(BundleCenter.current(cache, "shopping", publicKey))
        assertFalse(installed.root.exists())

        val again = BundleCenter.install(cache, "shop", publicKey, pack("bundleA"))
        val other = Ed25519KeyPairGenerator()
        other.init(Ed25519KeyGenerationParameters(SecureRandom()))
        val otherKey = (other.generateKeyPair().public as Ed25519PublicKeyParameters).encoded
        assertNull(BundleCenter.current(cache, "shop", otherKey))
        assertTrue(again.root.exists())
        assertEquals("bundleA", BundleCenter.current(cache, "shop", publicKey)?.id)
    }

    @Test
    fun rejectsABadSignatureAndAnExecutableEntry() {
        val zip = pack("bundleA")
        zip[zip.size / 2] = (zip[zip.size / 2] + 1).toByte()
        try {
            BundlePackage.open(zip, publicKey)
            throw AssertionError("坏包应被拒绝")
        } catch (error: BundleException) {
            assertTrue(
                error.failure == BundleFailure.SIGNATURE ||
                    error.failure == BundleFailure.DIGEST ||
                    error.failure == BundleFailure.LAYOUT ||
                    error.failure == BundleFailure.MANIFEST
            )
        }

        try {
            BundlePackage.open(markExecutable(pack("bundleA")), publicKey)
            throw AssertionError("可执行条目应被拒绝")
        } catch (error: BundleException) {
            assertEquals(BundleFailure.LAYOUT, error.failure)
        }
    }

    @Test
    fun listenerFailureDoesNotBlockInstall() {
        val seen = mutableListOf<BundleStage>()
        val listener = BundleListener { record ->
            seen.add(record.stage)
            throw IllegalStateException("埋点失败")
        }
        BundleCenter.addListener(listener)
        try {
            val ready = BundleCenter.load(cache, "shopping", publicKey) {
                val zip = pack("bundleA")
                BundleDownload("bundleA", zip, "shopping.browse", true)
            }
            assertEquals("bundleA", ready.id)
            assertEquals(listOf(BundleStage.FETCH, BundleStage.INSTALL), seen)
        } finally {
            BundleCenter.removeListener(listener)
        }
    }

    private fun pack(
        id: String,
        template: String = """{"layout":{"type":"column","layout":{"width":"fill","height":"fill"}}}"""
    ): ByteArray {
        val files = linkedMapOf(
            "routes.json" to """{"start":"list","pages":{"list":{"template":"templates/list.json","data":"data/list.json"},"detail":{"template":"templates/detail.json","data":"data/detail.json"}}}""".toByteArray(),
            "templates/list.json" to template.toByteArray(),
            "templates/detail.json" to template.toByteArray(),
            "data/list.json" to "{}".toByteArray(),
            "data/detail.json" to "{}".toByteArray()
        )
        val digest = BundlePackage.digest(files)
        val hex = digest.joinToString("") { "%02x".format(it) }
        val signer = Ed25519Signer()
        signer.init(true, Ed25519PrivateKeyParameters(privateKey, 0))
        signer.update(digest, 0, digest.size)
        val signature = Base64.getEncoder().encodeToString(signer.generateSignature())
        val manifest = """{"id":"$id","intent":"shopping.browse","sample":true,"createdAt":"2026-01-01T00:00:00Z","hash":"$hex","alg":"ed25519","signature":"$signature"}"""
        files["manifest.json"] = manifest.toByteArray()
        return storedZip(files)
    }

    private fun storedZip(files: Map<String, ByteArray>): ByteArray {
        val out = ByteArrayOutputStream()
        ZipOutputStream(out).use { zip ->
            for (name in listOf(
                "routes.json",
                "templates/list.json",
                "templates/detail.json",
                "data/list.json",
                "data/detail.json",
                "manifest.json"
            )) {
                val body = files.getValue(name)
                val entry = ZipEntry(name)
                entry.method = ZipEntry.STORED
                entry.size = body.size.toLong()
                entry.compressedSize = body.size.toLong()
                val crc = CRC32()
                crc.update(body)
                entry.crc = crc.value
                zip.putNextEntry(entry)
                zip.write(body)
                zip.closeEntry()
            }
        }
        return out.toByteArray()
    }

    private fun markExecutable(raw: ByteArray): ByteArray {
        val zip = raw.copyOf()
        val eocd = findEocd(zip)
        val count = u16(zip, eocd + 10)
        var offset = u32(zip, eocd + 16)
        repeat(count) {
            zip[offset + 4] = 0x14
            zip[offset + 5] = 0x03
            val external = 493 shl 16
            zip[offset + 38] = (external and 0xff).toByte()
            zip[offset + 39] = ((external ushr 8) and 0xff).toByte()
            zip[offset + 40] = ((external ushr 16) and 0xff).toByte()
            zip[offset + 41] = ((external ushr 24) and 0xff).toByte()
            val nameLen = u16(zip, offset + 28)
            val extraLen = u16(zip, offset + 30)
            val commentLen = u16(zip, offset + 32)
            offset += 46 + nameLen + extraLen + commentLen
        }
        return zip
    }

    private fun findEocd(raw: ByteArray): Int {
        for (index in raw.size - 22 downTo 0) {
            if (raw[index] == 0x50.toByte() &&
                raw[index + 1] == 0x4b.toByte() &&
                raw[index + 2] == 0x05.toByte() &&
                raw[index + 3] == 0x06.toByte()
            ) {
                return index
            }
        }
        throw IllegalStateException("zip 没有目录")
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
