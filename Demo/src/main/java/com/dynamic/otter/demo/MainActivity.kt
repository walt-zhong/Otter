package com.dynamic.otter.demo

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.LinearLayoutCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.dynamic.otter.ExpansionCenter
import com.dynamic.otter.OTEngine
import com.dynamic.otter.utils.AssetsUtils

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContentView(R.layout.activity_main)
        ViewCompat.setOnApplyWindowInsetsListener(findViewById(R.id.main)) { v, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            v.setPadding(systemBars.left, systemBars.top, systemBars.right, systemBars.bottom)
            insets
        }

        ExpansionCenter.instance.registerPageOpener { context, page ->
            DemoRoutes.open(context, page)
        }

        val template = OTEngine.instance
            .init(this)
            .buildTemplate("home-demo", "home", "templates/home-demo/home.json")
        template.setData(
            AssetsUtils.parseAssetsToString(this, "templates/home-demo/mock-data/home.json")
        )
        val rootView = OTEngine.instance.createAndroidView(template)
        findViewById<LinearLayoutCompat>(R.id.home_container).addView(rootView)
    }
}
