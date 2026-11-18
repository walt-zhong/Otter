# Demo

Web Demo 的页面分组和 Android Demo 相同。模版和数据在 `otter-web/templates`，开发服务器把这个目录映射成 `/client/templates`。矢量图、Lottie 和调试公钥仍读 `otter-android/Demo`。

```shell
cd otter-web
npm install
npm run dev
```

打开 `http://127.0.0.1:5174`。页面是一条 420 像素宽的竖屏，颜色和 Android 导航页一致：页面 `#F3EFE7`，卡片 `#FFFCF8`，强调色 `#C45C26`。

```shell
npm test
```

测试会走一遍 `otter-web/templates` 里的模版和 `routes*.json`，并覆盖缺字段、`size()`、`env('isAndroid')` 和 `env('isWeb')`。

## 导航

首页是原生列表，不是模版。分组是场景、组件、调试。点一项进入 `#/<page>`。顶栏返回先弹出当前 Otter 栈；栈里只剩一页时回到首页。南市若停在「订单」或「我的」，第一次返回先回到「首页」。

| 首页标题 | page | 模版 |
| --- | --- | --- |
| 南市 | `market` | `templates/market/routes.json`，以及 `routes-orders.json`、`routes-mine.json` |
| 权限 | `permission` | `templates/permission/routes.json` |
| 城南 | `stack` | `templates/stack/routes.json` |
| 天气 | `weather` | `templates/weather-card-demo/weather-card.json` |
| 行程 | `journey` | `templates/journey/journey.json` |
| 收件 | `inbox` | `templates/inbox/inbox.json` |
| 播放 | `player` | `templates/player/player.json` |
| 聊天 | `chat` | `templates/chat/chat.json` |
| 液态玻璃 | `glass` | `templates/glass/glass.json` |
| Column 到 Switch | 与 type 同名 | `templates/<type>/<type>.json` |
| 生成 | `bundle` | 签名包里的 `routes.json` |

组件页的数据在同目录的 `mock-data/`。播放页在模版画完之后由 `demo/player.ts` 推动进度、封面和队列，间隔 500 毫秒。南市的支付、数量、删除、刷新状态、拨号、筛选和切换底栏在 `demo/market.ts`。

矢量 XML 在请求 `/client/res/<name>.svg` 时转成 SVG。`glass_wallpaper` 使用 `drawable-nodpi` 里的 jpg。Lottie 从 `assets/animation/` 读取。

## 生成

调试分组里的「生成」对应 Android debug 包里的同一页。查询默认是「买个手机壳」，服务地址默认是 `http://127.0.0.1:8080`。页面上仍显示这个地址。发请求时，本机 8080 会改走当前页面的 `/api`，由 Vite 转到 Harbor，这样浏览器的跨域限制不会挡住调试。

先在 `otter-harbor` 启动服务：

```shell
go run ./cmd/ottersrv
curl http://127.0.0.1:8080/api/v1/health
```

返回 `{"status":"ok"}` 后，在 Demo 里点「生成」。公钥读的是 Android 调试包里的 `otter_dev_public.bin`。这一页的 fallback 是 `NONE`，验签失败不会改用旧包。没配模型时状态类似「离线 · shopping.browse · 示例」。配了模型密钥时，状态以「模型 · shopping.browse」开头。

地址改成别的主机时，请求会直接发到那个主机，不再走 `/api`。对方需要自己允许这个页面的来源。

## 和 Android Demo 的对应

| Android | Web |
| --- | --- |
| `MainActivity` 导航 | `demo/main.ts` 首页 |
| `MarketActivity` | `#/market`，三个 `PageStack` |
| `StackActivity`、`PermissionActivity` | `#/stack`、`#/permission` |
| `ComponentDemoActivity` | 单页 `OTEngine.show` |
| `PlayerSession` | `demo/player.ts` |
| `BundleDebugActivity` | `#/bundle` |
