package com.dynamic.otter.demo

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.LinearLayoutCompat
import com.dynamic.otter.nav.PageStack
import com.dynamic.otter.permission.AndroidPermissionCenter

class PermissionActivity : AppCompatActivity() {
    private var stack: PageStack? = null
    private var permissions: AndroidPermissionCenter? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        permissions = AndroidPermissionCenter.install(this)
        setContentView(R.layout.activity_stack)
        DemoTopBar.bind(this, "权限", showBack = true)
        stack = PageStack.attach(
            this,
            findViewById(R.id.main),
            findViewById<LinearLayoutCompat>(R.id.stack_container),
            "templates/permission/routes.json",
            "demo",
            "permission"
        )
    }

    override fun onDestroy() {
        permissions?.release()
        permissions = null
        stack?.release()
        stack = null
        super.onDestroy()
    }
}
