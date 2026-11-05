package com.dynamic.otter.demo

import android.os.Bundle
import android.view.View
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.TextView
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.dynamic.otter.bundle.BundleCenter
import com.dynamic.otter.bundle.BundleDownload
import com.dynamic.otter.bundle.BundleFallback
import com.dynamic.otter.bundle.InstalledBundle
import com.dynamic.otter.nav.PageStack
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.max

class BundleDebugActivity : AppCompatActivity() {
    private var stack: PageStack? = null
    private var bundleSource: String = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContentView(R.layout.activity_bundle_debug)
        DemoTopBar.bind(this, "生成", showBack = true)
        applyInsets()
        findViewById<View>(R.id.bundle_stage).clipToOutline = true

        val baseInput = findViewById<EditText>(R.id.bundle_base)
        val queryInput = findViewById<EditText>(R.id.bundle_query)
        val status = findViewById<TextView>(R.id.bundle_status)
        val submit = findViewById<TextView>(R.id.bundle_submit)
        val placeholder = findViewById<TextView>(R.id.bundle_placeholder)
        val container = findViewById<FrameLayout>(R.id.bundle_container)
        baseInput.setText(intent.getStringExtra(EXTRA_BASE_URL) ?: DEFAULT_BASE)
        if (queryInput.text.isEmpty()) {
            queryInput.setText("买个手机壳")
        }

        submit.setOnClickListener {
            val base = baseInput.text.toString().trim().trimEnd('/')
            val query = queryInput.text.toString().trim()
            if (query.isEmpty() || query.length > 200) {
                showStatus(status, "请输入 1 到 200 个字", error = true)
                return@setOnClickListener
            }
            submit.isEnabled = false
            submit.alpha = 0.45f
            showStatus(status, "正在生成", error = false)
            Thread {
                val outcome = runCatching { fetchBundle(base, query) }
                runOnUiThread {
                    submit.isEnabled = true
                    submit.alpha = 1f
                    outcome.onSuccess { ready ->
                        try {
                            stack?.release()
                            container.removeAllViews()
                            stack = PageStack.attach(
                                this,
                                container,
                                container,
                                "routes.json",
                                "debug",
                                ready.id,
                                ready.root
                            )
                            placeholder.visibility = View.GONE
                            showStatus(status, statusText(ready), error = ready.fellBack)
                        } catch (error: Exception) {
                            showStatus(status, error.message ?: "这个页面还打不开", error = true)
                        }
                    }.onFailure { error ->
                        showStatus(status, error.message ?: "请求失败", error = true)
                    }
                }
            }.start()
        }
    }

    private fun showStatus(status: TextView, message: String, error: Boolean) {
        status.visibility = View.VISIBLE
        status.text = message
        status.setTextColor(if (error) 0xFFC45C26.toInt() else 0xFF1F6F6A.toInt())
    }

    private fun applyInsets() {
        val root = findViewById<View>(R.id.main)
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            val ime = insets.getInsets(WindowInsetsCompat.Type.ime())
            view.setPadding(bars.left, bars.top, bars.right, max(bars.bottom, ime.bottom))
            insets
        }
        ViewCompat.requestApplyInsets(root)
    }

    private fun statusText(ready: InstalledBundle): String {
        if (ready.fellBack) {
            return "仍显示上次可用的模版"
        }
        val parts = mutableListOf<String>()
        when (bundleSource) {
            "model" -> parts.add("模型")
            "offline" -> parts.add("离线")
        }
        if (ready.intent.isNotEmpty()) {
            parts.add(ready.intent)
        }
        if (ready.sample) {
            parts.add("示例")
        }
        if (parts.isEmpty()) {
            return ready.id
        }
        return parts.joinToString(" · ")
    }

    private fun fetchBundle(base: String, query: String): InstalledBundle {
        val publicKey = resources.openRawResource(R.raw.otter_dev_public).use { it.readBytes() }
        return BundleCenter.load(
            cacheRoot = cacheDir,
            slot = "debug",
            publicKey = publicKey,
            fallback = BundleFallback.NONE
        ) {
            val meta = postJson("$base/api/v1/generate", JSONObject().put("query", query).toString())
            bundleSource = meta.optString("source", "")
            val id = meta.getString("id")
            val zip = getBytes("$base/api/v1/bundles/$id")
            BundleDownload(id, zip, meta.optString("intent", ""), meta.optBoolean("sample"))
        }
    }

    private fun postJson(url: String, body: String): JSONObject {
        val connection = open(url, "POST")
        connection.doOutput = true
        connection.setRequestProperty("Content-Type", "application/json")
        connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
        return readJson(connection)
    }

    private fun getBytes(url: String): ByteArray {
        val connection = open(url, "GET")
        val code = connection.responseCode
        val stream = if (code in 200..299) connection.inputStream else connection.errorStream
        val body = stream.use { it.readBytes() }
        if (code !in 200..299) {
            error(jsonMessage(body))
        }
        return body
    }

    private fun readJson(connection: HttpURLConnection): JSONObject {
        val code = connection.responseCode
        val stream = if (code in 200..299) connection.inputStream else connection.errorStream
        val body = stream.use { it.readBytes() }
        if (code !in 200..299) {
            error(jsonMessage(body))
        }
        return JSONObject(body.toString(Charsets.UTF_8))
    }

    private fun jsonMessage(body: ByteArray): String {
        return runCatching { JSONObject(body.toString(Charsets.UTF_8)).getString("message") }
            .getOrDefault("请求失败")
    }

    private fun open(url: String, method: String): HttpURLConnection {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.requestMethod = method
        connection.connectTimeout = 15_000
        // 服务端一次模型调用最多 30 秒，失败会再试一次。这里要盖住整段，否则手机会先提示超时。
        connection.readTimeout = 70_000
        return connection
    }

    override fun onDestroy() {
        stack?.release()
        stack = null
        super.onDestroy()
    }

    companion object {
        const val EXTRA_BASE_URL = "baseUrl"
        const val DEFAULT_BASE = "http://127.0.0.1:8080"
    }
}
