package com.dynamic.otter.demo

import android.content.Context
import android.content.Intent
import android.widget.Toast

object DemoRoutes {
    fun open(context: Context, page: String) {
        if (page == "stack") {
            context.startActivity(Intent(context, StackActivity::class.java))
            return
        }
        if (page == "market") {
            context.startActivity(Intent(context, MarketActivity::class.java))
            return
        }
        if (page == "weather") {
            context.startActivity(Intent(context, WeatherCardTemplateActivity::class.java))
            return
        }
        val spec = components[page]
        if (spec == null) {
            Toast.makeText(context, "没有这个示例", Toast.LENGTH_SHORT).show()
            return
        }
        context.startActivity(
            Intent(context, ComponentDemoActivity::class.java)
                .putExtra(ComponentDemoActivity.EXTRA_TEMPLATE, spec.template)
                .putExtra(ComponentDemoActivity.EXTRA_DATA, spec.data)
        )
    }

    private data class Spec(val template: String, val data: String)

    private val components = mapOf(
        "column" to Spec(
            "templates/column/column.json",
            "templates/column/mock-data/column.json"
        ),
        "row" to Spec(
            "templates/row/row.json",
            "templates/row/mock-data/row.json"
        ),
        "text" to Spec(
            "templates/text/text.json",
            "templates/text/mock-data/text.json"
        ),
        "image" to Spec(
            "templates/image/image.json",
            "templates/image/mock-data/image.json"
        ),
        "spacer" to Spec(
            "templates/spacer/spacer.json",
            "templates/spacer/mock-data/spacer.json"
        ),
        "list" to Spec(
            "templates/list/list.json",
            "templates/list/mock-data/list.json"
        ),
        "progress" to Spec(
            "templates/progress/progress.json",
            "templates/progress/mock-data/progress.json"
        ),
        "lottie" to Spec(
            "templates/lottie/lottie.json",
            "templates/lottie/mock-data/lottie.json"
        ),
        "input" to Spec(
            "templates/input/input.json",
            "templates/input/mock-data/input.json"
        ),
        "checkbox" to Spec(
            "templates/checkbox/checkbox.json",
            "templates/checkbox/mock-data/checkbox.json"
        ),
        "radio" to Spec(
            "templates/radio/radio.json",
            "templates/radio/mock-data/radio.json"
        ),
        "switch" to Spec(
            "templates/switch/switch.json",
            "templates/switch/mock-data/switch.json"
        ),
        "inbox" to Spec(
            "templates/inbox/inbox.json",
            "templates/inbox/mock-data/inbox.json"
        ),
        "journey" to Spec(
            "templates/journey/journey.json",
            "templates/journey/mock-data/journey.json"
        ),
        "player" to Spec(
            "templates/player/player.json",
            "templates/player/mock-data/player.json"
        ),
        "chat" to Spec(
            "templates/chat/chat.json",
            "templates/chat/mock-data/chat.json"
        )
    )
}
