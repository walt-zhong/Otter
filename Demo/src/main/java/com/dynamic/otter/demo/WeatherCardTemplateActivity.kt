package com.dynamic.otter.demo

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.LinearLayoutCompat

class WeatherCardTemplateActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContentView(R.layout.activity_weather_card_template)
        TemplateScreen.show(
            this,
            findViewById<LinearLayoutCompat>(R.id.weather_card_template_container),
            "templates/weather-card-demo/weather-card.json",
            "templates/weather-card-demo/mock-data/weather-card.json"
        )
    }
}
