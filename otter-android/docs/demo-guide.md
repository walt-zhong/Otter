# Demo 页面与真机调试

`:Demo` 用 assets 里的 JSON 把协议跑一遍，渲染走和业务相同的 `OTEngine`。`applicationId` 是 `com.senseauto.sensedyne.demo`。

```shell
./gradlew :Demo:assembleDebug
./gradlew :OTAndroid:testDebugUnitTest
```

启动 `MainActivity` 后是导航页，按场景和组件列出 Demo 里的示例。点一项把 `page` 交给 `DemoRoutes.open`，再启动对应 Activity。Debug 包多一项「生成」，打开查询下发页，步骤见下一节。真机或模拟器使用 arm64-v8a。

## 查询下发

「生成」只在 debug 包里。导航页点进去，查询默认是「买个手机壳」，服务地址默认是 `http://127.0.0.1:8080`。这一页没有桌面入口，`adb shell am start` 打不开。

服务在并列的 `otter-harbor`：

```shell
go run ./cmd/ottersrv
```

本机先确认它在听：

```shell
curl http://127.0.0.1:8080/api/v1/health
```

返回 `{"status":"ok"}` 后再装调试包。`gradlew` 没有执行权限：

```shell
bash ./gradlew :Demo:installDebug
```

手机上的 `127.0.0.1` 是手机自己，不是电脑。页面保持默认地址，用 USB 把手机的 8080 转到电脑：

```shell
adb reverse tcp:8080 tcp:8080
```

然后在导航页打开「生成」，点「生成」。成功后渲染区出现商品列表。没配模型时状态是「离线 · shopping.browse · 示例」。Debug 包允许明文 HTTP，所以这个地址不用改成 https。

这条转发跟着这根 USB 线。拔掉或重新插上之后，再执行一次 `adb reverse`。没转发时，页面显示 `Failed to connect to /127.0.0.1:8080`。

模拟器没有这条转发，地址改成 `http://10.0.2.2:8080`。手机和电脑在同一 Wi-Fi、不插线时，地址改成电脑当前的局域网地址，例如 `http://192.168.1.40:8080`。服务默认听 `:8080`，所有网卡都能进。macOS 上看本机地址可以用 `ipconfig getifaddr en0`。

服务端配了 `OTTER_LLM_API_KEY` 之后，同一次生成会先由 DeepSeek 判断意图。购物意图的模版由模型写，状态以「模型 · shopping.browse」开头。说不清要买什么时，状态是「模型 · clarify」，页面仍是内置的澄清页。没配密钥时，服务不访问模型。封面是 https 图片，手机需要能上网。

## 资源

```
Demo/src/main/assets/templates/
├── home-demo/
├── column/ row/ text/ image/ spacer/
├── list/ progress/ lottie/ input/ checkbox/ radio/ switch/
├── weather-card-demo/ journey/ inbox/ player/ chat/ glass/
├── stack/
├── market/
└── permission/
```

组件目录里，`*.json` 是模版，`mock-data/*.json` 是数据。多页流程用 `routes.json`。南市的订单和「我的」另有 `routes-orders.json`、`routes-mine.json`。

单页的渲染在 `TemplateScreen`：等容器有尺寸，处理系统栏和键盘，然后 `buildTemplate`、`setData`、`createAndroidView`。容器变了只 `relayout`。

## 入口

| 首页标题 | page | 模版 | Activity |
| --- | --- | --- | --- |
| 南市 | `market` | `templates/market/routes.json`，以及订单、我的两条路由 | `MarketActivity` |
| 权限 | `permission` | `templates/permission/routes.json` | `PermissionActivity` |
| 城南 | `stack` | `templates/stack/routes.json` | `StackActivity` |
| 天气 | `weather` | `templates/weather-card-demo/weather-card.json` | `WeatherCardTemplateActivity` |
| 行程 | `journey` | `templates/journey/journey.json` | `ComponentDemoActivity` |
| 收件 | `inbox` | `templates/inbox/inbox.json` | `ComponentDemoActivity` |
| 播放 | `player` | `templates/player/player.json` | `ComponentDemoActivity` |
| 聊天 | `chat` | `templates/chat/chat.json` | `ComponentDemoActivity` |
| 液态玻璃 | `glass` | `templates/glass/glass.json` | `ComponentDemoActivity` |
| Column 到 Switch | 与 type 同名 | `templates/<type>/<type>.json` | `ComponentDemoActivity` |

组件页是同一套版式：名称、一句说明，下面一组例子。返回在页面顶部的 Top bar。例子的标题在数据的 `sheet` 里，版式在模版的 `item` 里。

## 几条长一点的流程

天气卡是渐变、小时预报和一周趋势。行程是头图、进度和可滚动日程。收件是一长串会话。聊天是左右气泡和底部输入，用来看键盘 inset。

播放页在模版画完之后多挂了 `PlayerSession`。它按节点 tag 找到进度和 Lottie，在 SDK 外面驱动播放和拖动。协议里没有播放器节点。

液态玻璃背景是 `res:glass_wallpaper`，一张比屏幕高的彩图，从上到下是崖边小镇、花田和夜景街道。页面本身不滚动。上下拖动时只动这张图，玻璃留在原地，用来看边缘怎么折后面的画面。页上分成三种质地对比、染色对比，以及按住后变亮并可弹出提示。

城南的 `start` 是 `shelf`。四站共用 `place.json`，数据文件不同。地点页里的看点带上页面的颜色、标题和这一项的名称、时间，打开共用的 `stop`。看点页的勾选写回对应的那一项。右上角「记一句」打开 `memo`，返回时把 `$lines` 放进地点页的 `memos`。

南市的底栏是原生 Tab。三个 Tab 各挂一条 `PageStack`：

| Tab | 路由 | 里面有什么 |
| --- | --- | --- |
| 首页 | `templates/market/routes.json` | 店铺、购物车、支付。首页问定位，店铺问相机和麦克风，支付成功问通知 |
| 订单 | `routes-orders.json` | 订单列表 |
| 我的 | `routes-mine.json` | 换头像，并查看五项权限状态 |

说明文案在 `NanshiPermissions`，通过 `AndroidPermissionCenter.install` 装上。相册选中的头像用 `content:` 写回 `avatar`。

权限页把相机、麦克风、位置、相册、通知各放成一张卡片。每张都有查看、申请和去设置。状态文案来自写回的 `*StatusText`。系统不再弹框时，`*ShowSettings` 为 true。

协议约束有单元测试，命令是 `./gradlew :OTAndroid:testDebugUnitTest`。Demo 用来看布局、滚动、键盘和页面栈在真机上的样子。
