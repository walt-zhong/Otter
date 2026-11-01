# 接入

业务模块依赖 `:OTAndroid`，自己准备容器、模版和数据。字段见 [template-json.md](template-json.md)，节点见 [components.md](components.md)，运行时见 [architecture.md](architecture.md)。示例在 [demo.md](demo.md)。

## 环境

版本写在 `gradle/libs.versions.toml`。

- JDK 17
- `compileSdk` 36，`minSdk` 26。Demo 的 `targetSdk` 是 36
- Android Gradle Plugin 8.5.1，Kotlin 1.9.0，Gradle 8.7。插件官方测到 `compileSdk` 34，用 36 编译可以通过，同时会有一条兼容性提示
- 设备 ABI 为 arm64-v8a。`libstretch.so` 只有这个 ABI

```kotlin
implementation(project(":OTAndroid"))
```

仓库还没有 Maven 坐标。仓库外的工程要先把 `:OTAndroid` 拿进自己的构建。

## 画一页

模版和数据分成两个 assets 文件。容器量到宽高之后再 `createAndroidView`。Demo 把第一次布局、系统栏和键盘收在 `Demo/src/main/java/com/dynamic/otter/demo/TemplateScreen.kt`。

```kotlin
val template = OTEngine.instance
    .init(activity)
    .buildTemplate("card", "weather", "templates/weather-card-demo/weather-card.json")
template.setData(
    AssetsUtils.parseAssetsToString(activity, "templates/weather-card-demo/mock-data/weather-card.json")
)
val view = OTEngine.instance.createAndroidView(
    template,
    OTEngine.OTViewPortSize(container.width.toFloat(), container.height.toFloat())
) ?: return
container.addView(view, ViewGroup.LayoutParams(
    ViewGroup.LayoutParams.MATCH_PARENT,
    ViewGroup.LayoutParams.MATCH_PARENT
))
```

解析失败抛 `TemplateParseException`。未知 `type`、多出来的字段、指向不存在节点的 `target` 都停在这里。

离开页面时调用 `template.release()`。

## 尺寸和数据

容器宽高变了：

```kotlin
OTEngine.instance.relayout(
    template,
    OTEngine.OTViewPortSize(container.width.toFloat(), container.height.toFloat())
)
```

同一棵模版换成新数据时，先改 `TemplateContext.data`，再 `rebind`。已有 View 留着，文案、图片、勾选和列表按新数据写回。

`enableEdgeToEdge` 之后，系统栏和输入法从 `WindowInsets` 取。`TemplateScreen` 的底部 padding 取系统栏和键盘里较大的那个。

## 表达式

`setData` 收一份 JSON 对象字符串。模版里的 `"$title"` 就是这份对象的 `title`。列表的 `data` 求值结果要是对象数组，单项模版里的 `$` 读这一项。

带 `id` 的输入框会把当前文字写进页面数据。后面的事件可以读到 `$draft` 这种刚输入的字段。

## 单页跳转

当前 Activity 没有挂 `PageStack` 时，`open` 只把页面名交给宿主，不带 `params`。

```kotlin
ExpansionCenter.instance.registerPageOpener { context, page ->
    when (page) {
        "weather" -> context.startActivity(Intent(context, WeatherActivity::class.java))
        else -> Toast.makeText(context, "这个页面还打不开", Toast.LENGTH_SHORT).show()
    }
}
```

没注册，或页面名为空，点击 toast「这个页面还打不开」。`back` 结束当前 Activity。

自定义动作：

```kotlin
ExpansionCenter.instance.registerHostAction("refresh") { context, params ->
    val id = params?.getString("id")
}
```

```json
"reload": { "action": "host", "name": "refresh", "params": { "id": "$shopId" } }
```

`AndroidPermissionCenter.install` 会登记 `permissionCheck`、`permissionRequest`、`permissionOpenSettings`。之后再用同名 `registerHostAction` 会盖掉原来的权限动作。

## 一个 Activity 里的多页

路由只认 `start` 和 `pages`。城南的文件是 `templates/stack/routes.json`。

```kotlin
class StackHostActivity : AppCompatActivity() {
    private lateinit var stack: PageStack

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_stack)
        stack = PageStack.attach(
            this,
            findViewById(R.id.main),
            findViewById(R.id.stack_container),
            "templates/stack/routes.json",
            "demo",
            "stack"
        )
    }

    override fun onDestroy() {
        stack.release()
        super.onDestroy()
    }
}
```

`insetRoot` 接收系统栏和键盘的 padding，`container` 放当前页。路由不合法时 `attach` 抛异常。

`open` 先读那一页的 data 文件，再用 `params` 盖上去。`params` 可以是字符串、数字、布尔、对象或数组。`back` 可以带同样的 `params`。从列表项打开的页面，结果写回那一项；否则合并进上一页顶层，上一页按新数据重画。

系统返回键由栈处理。还有上一页就弹出，已经是首页则把事件交还 Activity。新页面从结束边滑入。容器还没有宽高，或系统关掉动画时，直接切换。

## 权限

```kotlin
AndroidPermissionCenter.install(this, PermissionPrompts.zh)
```

`params.capability` 取 `camera`、`microphone`、`location.whenInUse`、`photos`、`notifications`。申请前先显示宿主这张表里的句子，再走系统弹窗。相册打开系统选图。通知在 Android 13 以下视为已允许。

结果用能力前缀写回当前页。相机是 `cameraStatus`、`cameraStatusText`、`cameraShowSettings`，另外四项同样。`ShowSettings` 为 true 时系统不会再弹框。相册选中后还有 `photoSrc` 和 `avatar`。

安装包里没声明的权限，文案是「当前版本没有这项」。Demo 的声明在 `Demo/src/main/AndroidManifest.xml`。
