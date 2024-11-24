package com.dynamic.otter.demo

import android.annotation.SuppressLint
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.LinearLayoutCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.dynamic.otter.OTEngine
import com.dynamic.otter.render.node.DataBinding
import com.dynamic.otter.utils.AssetsUtils

class ProgressTemplateActivity : AppCompatActivity() {
    @SuppressLint("MissingInflatedId")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContentView(R.layout.activity_progress_template)
        ViewCompat.setOnApplyWindowInsetsListener(findViewById(R.id.main)) { v, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            v.setPadding(systemBars.left, systemBars.top, systemBars.right, systemBars.bottom)
            insets
        }

        val context = OTEngine.instance
            .init(this)
            .buildTemplate("progress-demo", "progress","templates/progress-demo/progress.xml")
        DataBinding.instance.buildTemplateData(
            AssetsUtils.parseAssetsToString(
                this,
                "templates/progress-demo/mock-data/progress.json"))
        val rootView = OTEngine.instance.createAndroidView(context)
        findViewById<LinearLayoutCompat>(R.id.progress_template_container).addView(rootView)
    }
}