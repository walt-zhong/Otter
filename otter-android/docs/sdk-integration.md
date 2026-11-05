# 接入 SDK

业务模块依赖 `:OTAndroid`，自己准备容器、模版和数据。对外入口是 `OTEngine`、`TemplateContext`、`PageStack`、`ExpansionCenter`、`AndroidPermissionCenter`、`BundleCenter`。字段见 [template-format.md](template-format.md)，节点见 [node-types.md](node-types.md)，运行时见 [render-pipeline.md](render-pipeline.md)。示例在 [demo-guide.md](demo-guide.md)。

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

## 服务端模版包

宿主下载签名 zip，`BundleCenter` 验签并落到缓存目录。渲染还是 `PageStack.attach`，`fileRoot` 用返回的 `root`。公钥由宿主传入。SDK 不发起网络请求。

`load` 和 `install` 会阻塞，放在后台线程。`slot` 是这个业务的缓存槽，只含字母、数字、点、下划线和短横线。一个槽只留最近一次完全通过的包。

```kotlin
val installed = BundleCenter.load(
    cacheRoot = cacheDir,
    slot = "shopping",
    publicKey = publicKey
) {
    val meta = api.generate(query)
    val zip = api.download(meta.id)
    BundleDownload(meta.id, zip, meta.intent, meta.sample)
}

PageStack.attach(
    this,
    insetRoot,
    container,
    "routes.json",
    "shopping",
    installed.id,
    installed.root
)
```

已经有缓存、想先画出来：

```kotlin
val cached = BundleCenter.current(cacheDir, "shopping", publicKey)
```

`current` 会重新验签。包被改过、读不出来时返回 null，并删掉这份缓存。签名对不上时保留文件并返回 null，换回原来的公钥还能读。换公钥之后，旧包不会再被画出来。

### 降级

写盘之前在内存里做完这些事：恰好六个约定文件、体积和 store 方式符合约定、ed25519 摘要和签名一致、路由和两份模版能被现有解析器接受、数据是 JSON 对象。任何一步失败，这个 zip 都不会进入缓存。

| `BundleFallback` | 失败之后 |
| --- | --- |
| `LAST_VERIFIED` | 默认。这个槽里还有上次通过的包，就再验一次并返回它。`fellBack` 为 true，`failure` 是这次的原因，`origin` 是 `CACHE`。 |
| `NONE` | 抛 `BundleException`。调试页用这个，失败时不画页面。 |

没有旧包，或旧包重新验签失败时，两种取值都抛 `BundleException`。业务捕获之后可以改画自己 assets 里的模版。SDK 不绑定某一份预置模版。

`BundleException.failure` 用来归类：

| 原因 | 含义 |
| --- | --- |
| `NETWORK` | 宿主拉取抛错，或没有返回 zip |
| `PUBLIC_KEY` | 公钥不是 32 字节 |
| `TOO_LARGE` | zip 或单个文件超限 |
| `LAYOUT` | 条目、压缩方式、符号链接或执行位不符合约定 |
| `MANIFEST` | manifest 字段、算法，或 id、intent、sample 对不上 |
| `DIGEST` | 摘要和 manifest 不一致 |
| `SIGNATURE` | 签名无效 |
| `PARSE` | 路由、模版或数据无法按现有规则解析 |
| `PATH` | 槽名或包内路径不合法 |
| `IO` | 通过校验之后没有写进缓存 |

### 统计

计数在进程内累计。`load` 记一次拉取和一次安装，`install` 只记安装。拉取成功表示宿主返回了 zip，后面验签失败仍然算下载成功。`current` 不计入这两项。

```kotlin
BundleCenter.addListener { record ->
    analytics.track(
        "otter_bundle",
        mapOf(
            "stage" to record.stage.name,
            "slot" to record.slot,
            "ok" to record.success,
            "failure" to record.failure?.name,
            "fallback" to record.fellBack,
            "bytes" to record.bytes,
            "ms" to record.durationMs
        )
    )
}

val stats = BundleCenter.snapshot()
stats.downloadSuccessRate
stats.usableRate
```

`downloadSuccessRate` 是拉取成功次数除以拉取次数。`usableRate` 是最终给出可渲染目录的次数除以安装次数，包含降级成功。监听器抛错不影响安装。`removeListener` 要传入同一次 `addListener` 的那个对象。

## 权限

```kotlin
AndroidPermissionCenter.install(this, PermissionPrompts.zh)
```

`params.capability` 取 `camera`、`microphone`、`location.whenInUse`、`photos`、`notifications`。申请前先显示宿主这张表里的句子，再走系统弹窗。相册打开系统选图。通知在 Android 13 以下视为已允许。

结果用能力前缀写回当前页。相机是 `cameraStatus`、`cameraStatusText`、`cameraShowSettings`，另外四项同样。`ShowSettings` 为 true 时系统不会再弹框。相册选中后还有 `photoSrc` 和 `avatar`。

安装包里没声明的权限，文案是「当前版本没有这项」。Demo 的声明在 `Demo/src/main/AndroidManifest.xml`。
