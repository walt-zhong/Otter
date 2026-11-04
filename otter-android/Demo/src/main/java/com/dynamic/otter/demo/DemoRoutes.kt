package com.dynamic.otter.demo

import android.content.Context
import android.content.Intent
import android.widget.Toast

object DemoRoutes {
    data class Entry(val page: String, val title: String, val desc: String, val tag: String)

    data class Section(val title: String, val entries: List<Entry>)

    val sections = listOf(
        Section(
            "场景",
            listOf(
                Entry("market", "南市", "街区店铺、购物车和订单", "店铺"),
                Entry("permission", "权限", "查看、申请、到设置里打开。相机、麦克风、位置、相册和通知", "能力"),
                Entry("stack", "城南", "四站、看点和备忘。勾选和句子会回到上一页", "栈"),
                Entry("weather", "天气", "渐变卡片、小时预报和一周趋势", "场景"),
                Entry("journey", "行程", "头图、进度和可滚动的日程", "场景"),
                Entry("inbox", "收件", "一长串会话，点开看是谁", "场景"),
                Entry("player", "播放", "封面、进度和控制", "场景"),
                Entry("chat", "聊天", "左右气泡和底部输入", "场景"),
                Entry("glass", "液态玻璃", "拖动背景，看磨砂、染色和按住变亮", "场景")
            )
        ),
        Section(
            "组件",
            listOf(
                Entry("column", "Column", "纵向容器的全部属性", "组件"),
                Entry("row", "Row", "横向容器的全部属性", "组件"),
                Entry("text", "Text", "文案、颜色、字号和对齐", "组件"),
                Entry("image", "Image", "本地图和网络图", "组件"),
                Entry("spacer", "Spacer", "留白、分割线和圆角", "组件"),
                Entry("list", "List", "纵向和横向都能滚很长", "组件"),
                Entry("progress", "Progress", "区间、颜色和动画", "组件"),
                Entry("lottie", "Lottie", "资源、重复和播放方式", "组件"),
                Entry("input", "Input", "文案、占位、键盘和字数", "组件"),
                Entry("checkbox", "CheckBox", "选中、颜色、全选和全不选", "组件"),
                Entry("radio", "Radio", "同组互斥、标签和颜色", "组件"),
                Entry("switch", "Switch", "开关、标签和颜色", "组件")
            )
        )
    )

    fun open(context: Context, page: String) {
        if (page == "stack") {
            context.startActivity(Intent(context, StackActivity::class.java))
            return
        }
        if (page == "market") {
            context.startActivity(Intent(context, MarketActivity::class.java))
            return
        }
        if (page == "permission") {
            context.startActivity(Intent(context, PermissionActivity::class.java))
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
                .putExtra(ComponentDemoActivity.EXTRA_TITLE, spec.title)
        )
    }

    private data class Spec(val template: String, val data: String, val title: String)

    private val components = mapOf(
        "column" to Spec(
            "templates/column/column.json",
            "templates/column/mock-data/column.json",
            "Column"
        ),
        "row" to Spec(
            "templates/row/row.json",
            "templates/row/mock-data/row.json",
            "Row"
        ),
        "text" to Spec(
            "templates/text/text.json",
            "templates/text/mock-data/text.json",
            "Text"
        ),
        "image" to Spec(
            "templates/image/image.json",
            "templates/image/mock-data/image.json",
            "Image"
        ),
        "spacer" to Spec(
            "templates/spacer/spacer.json",
            "templates/spacer/mock-data/spacer.json",
            "Spacer"
        ),
        "list" to Spec(
            "templates/list/list.json",
            "templates/list/mock-data/list.json",
            "List"
        ),
        "progress" to Spec(
            "templates/progress/progress.json",
            "templates/progress/mock-data/progress.json",
            "Progress"
        ),
        "lottie" to Spec(
            "templates/lottie/lottie.json",
            "templates/lottie/mock-data/lottie.json",
            "Lottie"
        ),
        "input" to Spec(
            "templates/input/input.json",
            "templates/input/mock-data/input.json",
            "Input"
        ),
        "checkbox" to Spec(
            "templates/checkbox/checkbox.json",
            "templates/checkbox/mock-data/checkbox.json",
            "CheckBox"
        ),
        "radio" to Spec(
            "templates/radio/radio.json",
            "templates/radio/mock-data/radio.json",
            "Radio"
        ),
        "switch" to Spec(
            "templates/switch/switch.json",
            "templates/switch/mock-data/switch.json",
            "Switch"
        ),
        "inbox" to Spec(
            "templates/inbox/inbox.json",
            "templates/inbox/mock-data/inbox.json",
            "收件"
        ),
        "journey" to Spec(
            "templates/journey/journey.json",
            "templates/journey/mock-data/journey.json",
            "行程"
        ),
        "player" to Spec(
            "templates/player/player.json",
            "templates/player/mock-data/player.json",
            "播放"
        ),
        "chat" to Spec(
            "templates/chat/chat.json",
            "templates/chat/mock-data/chat.json",
            "聊天"
        ),
        "glass" to Spec(
            "templates/glass/glass.json",
            "templates/glass/mock-data/glass.json",
            "液态玻璃"
        )
    )
}
