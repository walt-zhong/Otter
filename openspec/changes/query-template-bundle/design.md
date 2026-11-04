## Context

Otter 的模版和数据是两份 JSON。`:OTAndroid` 用 `TemplateJsonParser` 把模版收成节点树，用 `PageRouteParser` 读路由。路由只有 `start` 和 `pages`，每一页有 `template`，可以再有 `data`。页面名是标识符。`open` 先读目标页的 data 文件，再用事件 `params` 盖上去。列表项里的 `$` 读这一项。

今天这些文件都从 assets 读，入口集中在三处：

- `OTEngine.buildTemplate`（`OTAndroid/src/main/kotlin/com/dynamic/otter/OTEngine.kt`）只构造 `OTTemplate`，把 `templatePath` 放进 `TemplateContext`，不读文件。
- `OTEngine.createAndroidView` 用 `AssetsUtils.parseAssetsToString(context, template.templatePath)` 读模版，再交给 `TemplateJsonParser.parse`。
- `PageStack.attach` 用 `AssetsUtils.parseAssetsToString(activity, routePath)` 读路由。`PageStack.createShown` 用同一函数读 `entry.route.data`。`PageStack.materialize` 再次调用 `buildTemplate`，模版仍由 `createAndroidView` 读取。弹出后重画时数据已经在 `Frame.data` 里，不再读 data 文件。

`AssetsUtils.containedAssetPath` 拒绝空串、绝对路径、反斜杠、`.`、`..` 和 NUL。`TemplateScreen.show`、`MarketActivity` 和 `AnimationView` 的 `assets:` 动画仍走 assets。解析器不改。

Demo 的 `minSdk` 是 26，`compileSdk` / `targetSdk` 是 36。引擎是进程内单例 `OTEngine.instance`。`PageStack` 的状态键是 `com.dynamic.otter.nav.PageStack:` 加上 `routePath`。

本变更要一条调试闭环：一句话进 Go 服务，出来一个签名 zip，Android 调试页验签后从解压目录画出 `list`，点进 `detail`。iOS 以后收同一个包。仓库里还没有 `server/`。

## Goals / Non-Goals

**Goals**

- 在仓库根目录的 `server/` 提供意图识别、示例模版与数据、校验、ed25519 签名和 zip 下载。React 调试台提交 query 并看到意图、示例标记、文件列表和下载。
- 包内恰好六个文件。购物意图的页面名只有 `list` 和 `detail`。列表用 `open` 把当前商品带到详情。
- Android 调试构建能配置服务地址、拉取公钥和 zip、验签，并从解压目录交给现有 `PageStack` 渲染。验签失败或解析失败不画页面。
- 服务端测试固定密钥、不访问网络，作为包字节和签名的事实来源。

**Non-Goals**

- 网页管理端、真实商品目录、可视化编辑器、CDN、灰度发布。
- 把 React 打进 Go 二进制，或把调试页放进 release 包。
- 移植 `TemplateJsonParser` / `PageRouteParser`。服务端校验是契约的子集，设备上仍用现有解析器。
- iOS 渲染。iOS 只复用这里写死的 zip 契约。
- 改动画、图片的 `assets:` / `res:` 加载。生成页的封面使用 `https` 地址，由现有 Glide 加载。

## Decisions

### 1. 后端是同一个目录里的 Go 模块和 Vite 应用

`server/go.mod` 的 module 是 `otter/server`。Go 1.22，标准库完成 HTTP、zip、SHA-256 和 ed25519。不引入 web 框架。

```
server/cmd/ottersrv/main.go
server/internal/config/config.go
server/internal/httpserver/server.go
server/internal/intent/classify.go
server/internal/generate/offline.go
server/internal/generate/llm.go
server/internal/validate/validate.go
server/internal/bundle/zip.go
server/internal/bundle/sign.go
server/internal/bundle/store.go
server/internal/audit/audit.go
server/web/                      Vite + React + TypeScript
server/testdata/
```

`main` 读配置、构造签名器、内存包存储和 `http.Server`，默认监听 `:8080`（`OTTER_ADDR` 可改）。测试用 `httptest.Server` 调 `httpserver` 的 `Handler`，不绑定 8080。

React 由 Vite 单独起在 5173。v1 不把前端 embed 进 Go。调试台通过相对路径 `/api` 访问接口，API 进程仍可被 Android 直接调用。

这样拆是因为签名、校验和打包要在测试里确定性运行；界面只是这个 API 的一个调用方。

### 2. HTTP API

| 方法与路径 | 行为 |
| --- | --- |
| `POST /api/v1/generate` | 请求体 `{"query":"..."}`。成功 200：`{"id","intent","sample","sampleLabel","hash","files"}`。同时按 `id` 存下 zip。 |
| `GET /api/v1/bundles/{id}` | `application/zip`，body 是该 id 的 zip 字节。 |
| `GET /api/v1/pubkey` | `{"alg":"ed25519","publicKey":"<标准 base64，原始 32 字节>"}`。`Cache-Control: no-store`。 |
| `GET /api/v1/health` | 200 `{"status":"ok"}`。 |

`id` 是不含 `/` 与 `..` 的字符串。存储里没有则返回 404，JSON 含 `code`=`not_found` 与 `message`。

`query` 必须是 JSON 字符串，按 Unicode 码位计长 1 到 200。缺失、类型不对、空串或超过 200 时返回 400，JSON 含 `code`=`invalid_query` 与非空 `message`。校验失败返回 422，JSON 含 `code`=`template_invalid` 与非空 `message`。错误体不是 zip。

200 的字段：

- `intent`：`shopping.browse` 或 `clarify`。
- `sample`：购物为 `true`，澄清为 `false`。
- `sampleLabel`：购物为 `示例`，澄清为空字符串。
- `hash`：64 位小写十六进制，与 manifest 里的 `hash` 相同。
- `files`：按这个顺序的六个路径：`routes.json`、`templates/list.json`、`templates/detail.json`、`data/list.json`、`data/detail.json`、`manifest.json`。

`bundle.Store` 是带互斥锁的内存 map，上限 32 个，按写入顺序丢掉最旧的。进程退出后 id 失效，再次下载得到 404。调试服务不需要持久化和跨实例共享，内存存储让测试不用清理磁盘。

### 3. Zip 与哈希

Zip 使用 `archive/zip`，每个条目 `Method = zip.Store`。条目名只用正斜杠，无前导斜杠。不含目录条目、符号链接、重复名和这六个名字以外的条目。

六个文件的未压缩字节各自不超过 256 KiB（262144），合计不超过 1 MiB（1048576）。超出则不签名、不入库，返回 422。

| 条目 | 内容 |
| --- | --- |
| `routes.json` | `start` 为 `list`。`pages` 只有 `list` 和 `detail`。 |
| `templates/list.json` | 列表页模版。 |
| `templates/detail.json` | 详情页模版。 |
| `data/list.json` | 列表数据，含 `products` 数组。 |
| `data/detail.json` | 详情数据，含 `title`、`price`、`cover`。 |
| `manifest.json` | 算法、摘要、签名、意图和示例标记。不参与摘要。 |

路由固定为：

```json
{
  "start": "list",
  "pages": {
    "list": {
      "template": "templates/list.json",
      "data": "data/list.json"
    },
    "detail": {
      "template": "templates/detail.json",
      "data": "data/detail.json"
    }
  }
}
```

路径和 `PageRouteParser` 的相对路径一致，也和 assets 里 `templates/...` 的写法一致。模型不能改这张表；服务端在签名前写死它。

摘要按固定顺序拼接五个文件的 `路径\n十进制字节长度\n原始字节`。路径就是 zip 条目名。长度是 `len(bytes)` 的十进制，无前导零。换行是一个 `0x0A`。顺序是 `routes.json`、`templates/list.json`、`templates/detail.json`、`data/list.json`、`data/detail.json`。对拼接结果做 SHA-256，得到 32 字节。ed25519 对这 32 字节本身签名，不对拼接原文签，也不对 hex 或 base64 文本签。Go 侧是 `ed25519.Sign(private, digest)`，验证是 `ed25519.Verify(public, digest, signature)`。

`manifest.json`：

```json
{
  "alg": "ed25519",
  "hash": "<32 字节摘要的 64 位小写十六进制>",
  "signature": "<64 字节签名的标准 base64>",
  "intent": "shopping.browse",
  "sample": true,
  "sampleLabel": "示例"
}
```

manifest 放进 zip 是为了让 Android 在没有先调用 generate JSON 的情况下，只靠 zip 和公钥完成验签。它若被算进摘要，签名就无法写入同一份文件。

### 4. 密钥

`OTTER_SIGNING_KEY` 是标准 base64 的 64 字节 ed25519 私钥，布局与 Go 的 `ed25519.PrivateKey` 相同（前 32 字节种子，后 32 字节公钥）。解码长度不对，或后 32 字节与种子推导出的公钥不一致，进程拒绝启动。

环境变量为空时使用仓库内的调试密钥对（`server/internal/config/devkey.go`）。这把私钥只用于本地调试，Android 调试包内置与之成对的 32 字节公钥，不从网络取公钥。生产必须设置 `OTTER_SIGNING_KEY`，此时不再使用调试密钥。两种情况下都不把私钥打到日志。

测试注入同一把调试密钥，不生成随机密钥。因此同一输入的 zip 摘要和签名在测试里可逐字节比较。

### 5. 意图、离线生成和可选模型

分类器在 `intent.Classify`，只做子串匹配，顺序无关：`买`、`商品`、`购物`、`下单`、`手机壳`。命中则为 `shopping.browse`，否则为 `clarify`。`购买` 因为包含 `买` 而命中。页面图、允许的动作和提示词写在 `server/internal/intent` 与 `server/internal/generate` 的 Go 源码里，不放到数据库或管理端。

`OTTER_LLM_BASE_URL` 为空时，购物页走离线生成器。离线生成器用 Go 结构体表示模版节点和数据，`encoding/json` 输出。同一 query 用 SHA-256 的第一个字节选择两套手写布局之一（纵向卡片或横向行），保证测试稳定，也让两次不同的话可以看到不同排版。结构体字段按 `docs/template-format.md` 的必填项填写：节点有 `type` 和 `layout.width` / `layout.height`，列表有 `id`、`data`、`item`。不用 `text/template` 拼 JSON，避免手写串产生非法 JSON。

购物数据是固定的三件示例商品（手机壳一类的虚构标题）。`title`、`price`、`cover` 都是字符串，`cover` 是 `https` URL。`sample` 恒为 `true`，`sampleLabel` 恒为 `示例`。列表事件：

```json
{
  "openDetail": {
    "action": "open",
    "page": "detail",
    "params": {
      "title": "$title",
      "price": "$price",
      "cover": "$cover"
    }
  }
}
```

列表节点 `data` 为 `$products`，商品项 `onClick` 为 `["openDetail"]`。详情页展示 `$title`、`$price`、`$cover`，事件只有 `back`，可以再有一个 `toast`。`open` 必须带这三项 params，因为现有栈只把 params 叠到详情的 data 文件上，不会自动把列表项整对象拷过去。详情 data 文件放同名空串占位，点击后被 params 盖掉。

`clarify` 不论有没有配置模型，都用另一份手写页面：`data/list.json` 是 `{"products":[],"message":"请说明要看的商品，例如「买手机壳」。"}`，列表模版显示 `$message`，仍有 `data` 为 `$products` 的列表，列表项没有 `onClick`。事件里没有 `open`、`replace`、`popTo`。详情文件仍在，满足六个文件的契约，但从列表进不去。`sample` 为 `false`，`sampleLabel` 为 `""`。澄清没有商品可写，交给模型只会破坏「空列表、无 open」这个结果。

`OTTER_LLM_BASE_URL` 非空时，只有 `shopping.browse` 调用 OpenAI 兼容的 `POST {base}/chat/completions`（再加 `OTTER_LLM_API_KEY`、`OTTER_LLM_MODEL`）。请求要求模型只返回一个 JSON 对象，内含 `templates.list`、`templates.detail`、`data.list`、`data.detail`。服务端丢掉模型给出的路由和示例标记，改写为上面的固定路由，并强制 `sample=true`、`sampleLabel=示例`。模型可以改排版，不能改页面名。

模型输出先走第 6 节的校验。失败则把校验说明发回做一次修复。第二次仍失败、超时（30 秒）或 HTTP 失败，返回 422，不签名。已配置模型时不用离线结果顶替，免得把配置错误看成模型生成。测试注入 `http.RoundTripper` 或假的生成函数。默认 `http.Client` 不在测试里使用，测试不会拨出进程。

### 6. 服务端校验与设备上的二次解析

`validate.Validate` 在签名之前运行，购物和澄清都检查：

- 恰好六个名字，Store 方法，大小限制。
- `routes.json` 与第 3 节的固定文档一致，能被同一套字段约束接受：`start`、`pages`，页面名是标识符，`template` 与 `data` 是非空字符串。
- 两份模版是 JSON 对象，且含 `layout`。遍历 `events`，`action` 只允许 `open`、`back`、`toast`。`open.page` 只能是字面量 `detail`。禁止 `host`、`setText`、`append`、`replace`、`popTo` 以及协议里的其它动作。
- 列表模版有且只有一个 `type=list` 的节点，其 `data` 恰好是 `$products`。
- 详情模版的文本里出现 `$title`、`$price`、`$cover`。
- `data/list.json` 是对象，`products` 是数组；购物时至少一项，每项的 `title`、`price`、`cover` 是非空字符串，且 `cover` 以 `https://` 开头。澄清时 `products` 为空数组，`message` 为非空字符串，且事件中没有 `open`。
- `data/detail.json` 含字符串字段 `title`、`price`、`cover`。

这是契约校验，不是 Kotlin 解析器的移植。设备调试页在 `PageStack.attach` 之前用现有的 `PageRouteParser.parse` 和 `TemplateJsonParser.parse` 解析路由和两份模版。任一抛 `TemplateParseException` 或其它解析错误，删除解压目录，界面留下错误，不调用 `attach`。这样模型绕过子集校验时，整包被丢掉，而不是画出半页。解析器代码保持不动。

### 7. 审计

`log/slog` 的 JSON 写到 stdout。每次成功生成打一条：`query`、`intent`、`id`、`hash`。不打模版正文、数据正文、签名和私钥。失败可以打意图和校验说明，同样不打模版正文。

### 8. React 调试台

`server/web` 是单页，没有路由。一个输入框提交 query；结果区显示 `intent`、当 `sample` 为真时的 `sampleLabel` 药丸（文案为 `示例`）、`files` 列表，以及指向 `/api/v1/bundles/{id}` 的下载链接。400、422 和网络失败显示响应里的 `error`，不显示下载链接。

`vite.config.ts` 把 `/api` 代理到 `http://127.0.0.1:8080`。页面使用相对路径 `/api/v1/...`，开发时浏览器只和 5173 说话。

### 9. Android 从解压目录读模版

文件根目录挂在这一次渲染的对象上，不挂到 `OTEngine.instance`。引擎是进程单例，全局根目录会让南市等 assets 页面读到调试包。

新增 `AssetsUtils.readRelative(root: File, path: String): String`：

1. 先调用现有 `containedAssetPath`。拒绝时抛 `IllegalArgumentException("资源路径越界")`，与 `parseAssetsToString` 相同。
2. 再取 `root.canonicalFile` 和 `File(root, safe).canonicalFile`，要求目标等于根目录，或位于根目录加分隔符的前缀之下。挡住符号链接跳出目录的情况。
3. 读取 UTF-8 文本。

`parseAssetsToString` 保持原样。`OTAndroid/src/test` 里为 `readRelative` 增加与 `AssetsUtilsTest` 相同的越界用例，外加一个落在临时目录内的成功读取。

插入点：

- `OTEngine.OTTemplate` 增加 `fileRoot: File? = null`。`buildTemplate(bizId, templateId, templatePath, fileRoot: File? = null)` 把它存进去。现有调用不传这个参数，行为不变。
- `createAndroidView` 在现在调用 `parseAssetsToString` 的位置分支：`template.fileRoot` 非空时改走 `readRelative`，然后仍是 `TemplateJsonParser.parse`。
- `PageStack` 增加私有字段 `fileRoot: File?`。现有六参数 `attach` 传入 `null`。新增重载，最后一参为 `fileRoot: File`。重载用 `readRelative(fileRoot, routePath)` 读路由，再 `PageRouteParser.parse`。
- `createShown` 读 `entry.route.data` 时走同一个分支，并在 `buildTemplate` 上传入该 `fileRoot`。
- `materialize` 的 `buildTemplate` 也传入该 `fileRoot`。这里是旋转或返回上一页时重新读模版的路径。

`TemplateScreen`、`MarketActivity`、`AnimationView` 不改。调试页调用：

```kotlin
PageStack.attach(
    activity, insetRoot, container,
    "routes.json", "debug", bundleId,
    unpackDir
)
```

`routes.json` 是解压根目录下的相对路径。状态键因此是 `com.dynamic.otter.nav.PageStack:routes.json`。调试页同一时间只挂一条栈；换一个包之前先 `release()`，再 attach 新的解压目录。旋转后 Activity 用自己保存的解压目录重新 attach，`PageStack` 仍按现有逻辑恢复页面数据。

### 10. 调试页、公钥和验签

新源集只有 `Demo/src/debug`：`BundleDebugActivity`、调试清单和调试网络安全配置。release 合并不到这些文件。调试清单为这个 Activity 增加启动入口，并 `tools:replace` 应用的 `networkSecurityConfig`。`src/debug/res/xml/network_security_config.xml` 允许明文，便于模拟器访问 `http://10.0.2.2:8080` 和局域网主机。release 不带这份配置。Demo 已有 `INTERNET` 权限。

地址优先级：Intent 字符串 extra `baseUrl`，否则界面上的输入框，否则 `http://10.0.2.2:8080`。extra 写入输入框的初值，方便改主机。查询框把 query POST 到 `{base}/api/v1/generate`，结果区与 React 相同：意图、示例药丸、文件名、错误。

渲染时只 `GET {base}/api/v1/bundles/{id}`。公钥是调试包内的 32 字节原始公钥，与服务端默认调试密钥成对，不请求 `/api/v1/pubkey`。Zip 在设备上再查一遍六个名字、Store 方法和大小，然后按第 3 节重算摘要。验签使用 BouncyCastle `Ed25519`，消息是 32 字节摘要。依赖 `org.bouncycastle:bcprov-jdk18on` 只加在 Demo 的 debug 实现上，不进 `:OTAndroid`。签名或摘要失败显示错误并停止，不写缓存、不画页面。服务端若改用另一把 `OTTER_SIGNING_KEY`，调试包里的公钥对不上，验签失败，这是预期行为。

验签通过后解压到 `cacheDir/otter-bundles/{id}/`。只写出那六个相对路径上的普通文件，写前用 `containedAssetPath` 和规范化路径检查。然后做第 6 节的设备预解析，通过才 `attach`。

### 11. CORS

`httpserver` 对来源恰好为 `http://localhost:5173` 的请求返回：

- `Access-Control-Allow-Origin: http://localhost:5173`
- `Access-Control-Allow-Methods: GET, POST, OPTIONS`
- `Access-Control-Allow-Headers: Content-Type`
- `Vary: Origin`

其它来源不回放 `Allow-Origin`。不带凭证。`OPTIONS` 返回 204。Vite 代理下浏览器认为接口同源，这条头覆盖调试时直接打开 `127.0.0.1:8080` 的页面。允许的来源只有这一个，因为调试台的开发地址是固定的。

## Risks / Trade-offs

- 服务端校验比 `TemplateJsonParser` 窄。模型输出可能通过 200，到手机上预解析失败。预解析失败整包丢弃，用户看到错误。修复仍以服务端那一次为准，设备不再请求模型。
- 离线布局只有两套手写结构。换排版的幅度限于这两套，换来的是离线路径不会产生非法 JSON。
- 内存里最多 32 个 zip，重启即失。调试下载链接会过期。避免在本变更里做磁盘清理和权限。
- 调试私钥写在仓库里，只配对调试包里的公钥。生产必须换 `OTTER_SIGNING_KEY`。审计日志不包含私钥。
- 调试页不拉取公钥，因此不会把攻击者的公钥钉进应用。签名对不上内置公钥时直接拒绝。release 包没有这个页面。
- 示例封面是 `https` 图片。模拟器没有外网时列表仍在，图可能空白。地址不允许 `file:`、`assets:` 或 `res:`，避免包里的字符串去读本地资源。
- 多个调试栈若同时使用相对路径 `routes.json`，会共用 `PageStack` 的状态键。调试页在替换包之前 `release()`，同一 Activity 只留一条栈。
- BouncyCastle 只进 debug APK。release 依赖树不变。验签代码放在 `Demo/src/debug`，库模块不出现密码实现。

## Migration Plan

1. 添加 `server/` 模块、固定测试密钥和上述包。现有 Gradle 工程不引用它。先让 `go test ./...` 覆盖分类、离线包、签名、修复一次后的 422、未知 id 的 404，以及假 RoundTripper。
2. 在 `:OTAndroid` 按第 9 节加 `readRelative`、`buildTemplate` 的 `fileRoot` 和 `PageStack.attach` 重载。原六参数 `attach` 和 assets 演示保持原调用。补 `readRelative` 的 JVM 测试。
3. 加 `Demo/src/debug` 的调试页、清单和明文配置。debug 包出现第二个启动图标；release 包没有这个 Activity。
4. 本地同时运行 `go run ./cmd/ottersrv` 与 `server/web` 的 Vite。模拟器用默认 `10.0.2.2`，真机在输入框或 `baseUrl` extra 里写电脑的局域网地址。
5. iOS 以后按同一六个文件、同一摘要顺序和同一原始 32 字节签名验证。本变更不改 iOS 工程。

回退时停掉服务进程即可。库的新增参数有默认值，旧调用不依赖新服务。删除 `Demo/src/debug` 后 debug 包回到只有原来的 Demo。没有需要迁移的持久数据。

## Open Questions

无。本变更的产品决定已在提案中锁定。
