package com.dynamic.otter.demo

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.LinearLayoutCompat
import com.dynamic.otter.nav.PageStack

class StackActivity : AppCompatActivity() {
    private var stack: PageStack? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContentView(R.layout.activity_stack)
        DemoTopBar.bind(this, "城南", showBack = true)
        stack = PageStack.attach(
            this,
            findViewById(R.id.main),
            findViewById<LinearLayoutCompat>(R.id.stack_container),
            "templates/stack/routes.json",
            "demo",
            "stack"
        )
    }

    override fun onDestroy() {
        stack?.release()
        stack = null
        super.onDestroy()
    }
}
