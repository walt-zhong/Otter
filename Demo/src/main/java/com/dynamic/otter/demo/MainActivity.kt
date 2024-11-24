package com.dynamic.otter.demo

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

class MainActivity : AppCompatActivity() {
    @SuppressLint("MissingInflatedId")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContentView(R.layout.activity_main)
        ViewCompat.setOnApplyWindowInsetsListener(findViewById(R.id.main)) { v, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            v.setPadding(systemBars.left, systemBars.top, systemBars.right, systemBars.bottom)
            insets
        }

        findViewById<Button>(R.id.btn_layout_temp).setOnClickListener {
            val intent = Intent(this, LayoutDemoActivity::class.java)
            startActivity(intent)
        }

        findViewById<Button>(R.id.btn_text_temp).setOnClickListener {
            val intent = Intent(this, LayoutTextTemplateActivity::class.java)
            startActivity(intent)
        }

        findViewById<Button>(R.id.btn_list_temp).setOnClickListener {
            val intent = Intent(this, ListTemplateActivity::class.java)
            startActivity(intent)
        }

        findViewById<Button>(R.id.btn_progress_temp).setOnClickListener {
            val intent = Intent(this, ProgressTemplateActivity::class.java)
            startActivity(intent)
        }

        findViewById<Button>(R.id.btn_weather_card_temp).setOnClickListener {
            val intent = Intent(this, WeatherCardTemplateActivity::class.java)
            startActivity(intent)
        }

        findViewById<Button>(R.id.btn_animation_temp).setOnClickListener {
            val intent = Intent(this, AnimationActivity::class.java)
            startActivity(intent)
        }

        findViewById<Button>(R.id.btn_scaffold_temp).setOnClickListener {
            val intent = Intent(this, ScaffoldActivity::class.java)
            startActivity(intent)
        }

        findViewById<Button>(R.id.btn_tablayout_demo).setOnClickListener {
            val intent = Intent(this, TabLayoutVp2Activity::class.java)
            startActivity(intent)
        }

    }
}