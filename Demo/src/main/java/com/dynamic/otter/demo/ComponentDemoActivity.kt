package com.dynamic.otter.demo

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.LinearLayoutCompat

class ComponentDemoActivity : AppCompatActivity() {
    private var playerSession: PlayerSession? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContentView(R.layout.activity_component)
        val templatePath = intent.getStringExtra(EXTRA_TEMPLATE)
        val dataPath = intent.getStringExtra(EXTRA_DATA)
        if (templatePath.isNullOrBlank() || dataPath.isNullOrBlank()) {
            finish()
            return
        }
        TemplateScreen.show(
            this,
            findViewById<LinearLayoutCompat>(R.id.component_container),
            templatePath,
            dataPath
        ) { root ->
            if (templatePath.endsWith("templates/player/player.json")) {
                playerSession = PlayerSession.attach(root)
            }
        }
    }

    override fun onDestroy() {
        playerSession?.release()
        playerSession = null
        super.onDestroy()
    }

    companion object {
        const val EXTRA_TEMPLATE = "template"
        const val EXTRA_DATA = "data"
    }
}
