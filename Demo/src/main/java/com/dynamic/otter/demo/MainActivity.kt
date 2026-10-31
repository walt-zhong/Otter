package com.dynamic.otter.demo

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.LinearLayoutCompat
import com.dynamic.otter.ExpansionCenter

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContentView(R.layout.activity_main)
        ExpansionCenter.instance.registerPageOpener { context, page ->
            DemoRoutes.open(context, page)
        }
        TemplateScreen.show(
            this,
            findViewById<LinearLayoutCompat>(R.id.home_container),
            "templates/home-demo/home.json",
            "templates/home-demo/mock-data/home.json"
        )
    }
}
