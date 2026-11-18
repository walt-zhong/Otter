# 接入 SDK

页面自己准备容器、模版和数据。入口在 `src/index.ts`：`OTEngine`、`PageStack`、`ExpansionCenter`、`PermissionCenter`、`BundleCenter`。字段见 [template-format.md](../../otter-android/docs/template-format.md)，节点见 [node-types.md](../../otter-android/docs/node-types.md)，运行时见 [render-pipeline.md](render-pipeline.md)。

包还没有发布到 npm。业务工程可以直接依赖这个目录，或把 `src/` 拷进自己的构建。运行依赖是 `yoga-layout`、`lottie-web` 和 `@noble/ed25519`。

## 画一页

容器量到宽高之后再画。尺寸为 0 时会等下一次布局。

```ts
import { OTEngine, parseData } from "./src/index"

const engine = new OTEngine({ assetBase: "/assets", density: 1 })
const view = engine.show(container, templateText, parseData(dataText), () => {
  // 单页上的 back 走到这里
})
```

`assetBase` 用来解析 `res:` 和 `assets:`。Demo 里它是 `/client`：`res:ic_scene_coast` 变成 `/client/res/ic_scene_coast.svg`，`assets:animation/lottie-sunny` 变成 `/client/animation/lottie-sunny.json`。`http`、`https`、`blob` 和 `data` 原样使用。

解析失败抛 `TemplateParseException`。离开页面时调用 `view.release()`。

容器变了，`ResizeObserver` 会 `relayout`。换成新数据时改 `view.data`，再 `view.rebind()`。`setText` 写过的文案会留到下一次 `rebind` 清掉之前。

密度默认是 1，1 dp 等于 1 CSS 像素。放进手机宽度的框里时，和 Android 的 dp 布局对齐。

## 表达式和输入

`" $title "` 这类以 `$` 开头的字符串读当前数据。列表的 `data` 求值结果要是对象数组，单项里的 `$` 读这一项。

带 `id` 的输入框会把当前文字写进 `data[id]`，然后再派发 `onChange`。后面的事件可以读到刚输入的字段。勾选、单选和开关同样写 `data[id]`。

`env('isAndroid')` 和 `env('isiOS')` 在 Web 上为假。`env('isWeb')` 为真。不认识的 `env` 名字会让这个表达式保留原文。

## 多页

```ts
const stack = await engine.stack({
  container,
  routeText,
  loadText: (path) => fetch(path).then((response) => response.text()),
  onFinish: () => {
    // 栈里只剩一页时再 back
  },
})
stack.activate()
```

`routes.json` 只认 `start` 和 `pages`。`open` 先读该页的数据文件，再用事件参数盖上去。栈顶已经是同一页、且覆盖字段相同，则这次 `open` 不做。最深 32 层。

`PageStack.current` 是当前栈。Demo 的南市有三套栈，切换底栏时调用 `activate()`。`PageStack.find(element)` 从节点往上找 `.otter-stage`。

离开时 `stack.release()`。

没有页面栈的单页里，`open` 交给 `ExpansionCenter.pageOpener`。没注册，或页面名为空，toast「这个页面还打不开」。

## 宿主动作

模版里的 `host` 事件只带名字和参数。业务在打开页面前注册：

```ts
import { ExpansionCenter } from "./src/index"

ExpansionCenter.registerHostAction("pay", (params) => {
  const amount = String(params?.amount ?? "")
})
```

没注册时 toast「这个操作还不能用」。Demo 里的支付、数量、筛选和播放都走这条路径，实现在 `demo/`，不在 SDK 里。

## 权限

```ts
import { PermissionCenter, permissionPrompts, publishAll } from "./src/index"

PermissionCenter.install(permissionPrompts())
await publishAll()
```

`permissionPrompts()` 是通用说明。南市换成自己的标题和正文，键仍是 `camera`、`microphone`、`location.whenInUse`、`photos`、`notifications`。

三个宿主动作是 `permissionCheck`、`permissionRequest`、`permissionOpenSettings`。申请前先弹出说明，用户点继续才走浏览器授权。结果写进当前栈的数据：`*Status`、`*StatusText`、`*ShowSettings`。相册选中一张后额外写 `photoSrc`、`avatar`、`photoVisible`，值是 `blob:` 地址。

状态文案和 Android 对齐，例如「已允许」「已允许，精确位置」「已关闭，要到系统设置里打开」「当前版本没有这项」「还没问过」「已选好一张」「还没选过」。

浏览器不允许页面打开系统设置。`permissionOpenSettings` 提示到网站设置里打开，然后重新查一次当前状态。

## 签名包

宿主自己下载 zip。SDK 验签、校验模版，并按槽缓存。

```ts
import { BundleCenter, browserCache } from "./src/index"

const ready = await BundleCenter.load(
  browserCache(),
  "debug",
  publicKey,
  async () => ({ id, zip, intent, sample }),
  "NONE"
)
```

`publicKey` 是 32 字节。`fallback` 为 `LAST_VERIFIED` 时，新包失败会退回这个槽里上一份验过的包；`NONE` 则失败直接抛 `BundleException`。Demo 的生成页用 `NONE`。

`ready.files` 的键是包内路径，值是 UTF-8 文本。把它传给 `engine.stack` 的 `files`，页面栈优先读这里。

浏览器里的缓存是 IndexedDB，库名 `otter-web`，对象仓库 `bundles`。测试可以用 `memoryCache()`。`current()` 会重新验签，失败时返回 null，不删掉槽里的内容。

监听安装过程用 `addListener`。监听器自己抛错不会让安装失败。统计在 `snapshot()`：`downloadSuccessRate` 和 `usableRate`。

失败原因是 `NETWORK`、`PUBLIC_KEY`、`TOO_LARGE`、`LAYOUT`、`MANIFEST`、`DIGEST`、`SIGNATURE`、`PARSE`、`PATH`、`IO`。包的文件约定见 [架构](../../docs/architecture.md)。
