## ADDED Requirements

### Requirement: 生成请求
服务 MUST 提供 `POST /api/v1/generate`。请求体 MUST 是 JSON 对象 `{"query": string}`，`Content-Type` 为 `application/json`。成功时 MUST 返回 HTTP 200 与 JSON，至少包含字符串 `id`、字符串 `intent` 和布尔值 `sample`，且 MUST NOT 在该 JSON 中返回模版正文。`sample` MUST 与所存 zip 内 manifest 的 `sample` 相同。由生成器写出商品时，`sample` MUST 为 `true`。

#### Scenario: 合法查询返回包元数据
- **WHEN** 客户端 POST `{"query":"手机壳"}` 且生成成功
- **THEN** 响应为 HTTP 200 的 JSON，含非空 `id`、`intent` 与布尔 `sample`，响应体不是 zip

#### Scenario: 生成器写出的商品标记为示例
- **WHEN** 成功响应对应的包里，商品数组由生成器写入且非空
- **THEN** JSON 的 `sample` 与 manifest 的 `sample` 都是 `true`

### Requirement: 查询长度
`query` MUST 按 Unicode 码位（Go rune）计长，长度 MUST 在 1 到 200 之间（含端点）。缺字段、类型不是字符串、空字符串、或长度超过 200 时，服务 MUST 返回 HTTP 400，JSON 含非空 `code`（值为 `invalid_query`）与非空 `message`，且 MUST NOT 返回 zip，也 MUST NOT 保存包。

#### Scenario: 二百个汉字可以生成
- **WHEN** `query` 是 200 个「买」
- **THEN** 服务按长度接受该请求并返回 HTTP 200 的购物包元数据

#### Scenario: 空串与超长被拒绝
- **WHEN** `query` 为空字符串、缺失、不是字符串，或长度为 201 个码位
- **THEN** 响应为 HTTP 400，`code` 为 `invalid_query`，正文不是 zip，且没有可下载的新包

#### Scenario: 中文按码位而不是按字节截断
- **WHEN** `query` 是 200 个汉字（UTF-8 长度为 600 字节）
- **THEN** 服务 MUST 接受该长度，MUST NOT 因字节数超过 200 而返回 400

### Requirement: 本地 HTTP 与生产 HTTPS
供自动化测试和本地调试启动的服务 MUST 通过 HTTP 提供 `/api/v1/generate` 与 `/api/v1/bundles/{id}`，测试 MUST NOT 依赖 TLS。生产部署 MUST 只通过 HTTPS 暴露同一 API。

#### Scenario: 测试客户端走 HTTP
- **WHEN** 测试进程按本地调试配置请求生成接口
- **THEN** 请求使用 HTTP，并且在不配置客户端证书的情况下可以得到生成结果

#### Scenario: 生产只暴露 HTTPS
- **WHEN** 按生产部署要求对外提供该 API
- **THEN** 对外入口是 HTTPS，明文 HTTP 不是生产入口

### Requirement: 购物意图
当查询是在买东西、购物或找商品时，`intent` MUST 为 `shopping.browse`。内置生成器在无模型时也 MUST 把包含「买」「商品」「购物」「下单」或「手机壳」的合法查询识别为 `shopping.browse`。

#### Scenario: 指定购物词识别为浏览商品
- **WHEN** 查询分别为 `买咖啡`、`商品列表`、`购物车`、`我要下单`、`透明手机壳`，且长度合法
- **THEN** 每一次成功响应的 `intent` 都是 `shopping.browse`

#### Scenario: 非购物查询不是购物意图
- **WHEN** 查询为 `今天星期几`
- **THEN** `intent` 不是 `shopping.browse`

### Requirement: 固定页面图
`shopping.browse` 的页面图 MUST 固定为 `list` 与 `detail`。生成器（含模型输出）MUST NOT 发明其他页面名。`routes.json` 的 `start` MUST 为 `list`。若候选结果含有其他页面名，服务 MUST 丢弃整包，返回 HTTP 422，JSON 的 `code` 为 `template_invalid`，且 MUST NOT 返回 zip。

#### Scenario: 购物包只有列表和详情
- **WHEN** 生成 `shopping.browse` 包并读取 `routes.json`
- **THEN** `start` 为 `list`，`pages` 的键恰好是 `list` 与 `detail`

#### Scenario: 发明页面名被拒绝
- **WHEN** 生成结果的 routes 含有 `cart` 或其他不是 `list`、`detail` 的页面名
- **THEN** 响应为 HTTP 422，`code` 为 `template_invalid`，响应体不是 zip

### Requirement: 列表模版与打开详情
`shopping.browse` 的 `templates/list.json` MUST 含有 `type` 为 `list` 的节点，且该节点的 `data` 为 `$products`。列表项的点击 MUST 触发 `action` 为 `open`、`page` 为 `detail` 的事件。该事件的 `params` MUST 包含 `title`、`price`、`cover`，并分别绑定当前项的 `$title`、`$price`、`$cover`。列表模版 MUST 绑定 `$sampleLabel` 以展示示例标记。

#### Scenario: 列表绑定商品数组
- **WHEN** 解析购物包的列表模版
- **THEN** 存在 `list` 节点且其 `data` 为 `$products`，模版中含有 `$sampleLabel`

#### Scenario: 点击商品打开详情并带上三项参数
- **WHEN** 用户点击列表中的一项
- **THEN** 导航事件为 `open`，页面名为 `detail`，参数 `title`、`price`、`cover` 来自该项对应字段

### Requirement: 详情模版
`shopping.browse` 的 `templates/detail.json` MUST 读取 `$title`、`$price` 与 `$cover`。它 MUST 含有一个 `action` 为 `back` 的事件，并且有节点的 `onClick` 引用该事件。打开详情后，页面展示的标题、价格和封面 MUST 等于被点击商品的 `title`、`price` 与 `cover`。

#### Scenario: 详情绑定三项字段且可以返回
- **WHEN** 解析购物包的详情模版
- **THEN** 模版含有 `$title`、`$price`、`$cover`，并有被点击绑定的 `back` 动作

#### Scenario: 详情展示被点击的商品
- **WHEN** 从列表打开某一商品的详情
- **THEN** 详情上的标题、价格和封面等于该商品在 `products` 中的 `title`、`price` 与 `cover`

### Requirement: 示例商品数据
`shopping.browse` 的 `data/list.json` MUST 含有非空数组 `products`。每个元素 MUST 是对象，且 `title`、`price`、`cover` 都是非空字符串。同一文件的 `sample` MUST 为 `true`，`sampleLabel` MUST 恰好为「示例」。manifest 的 `sample` MUST 为 `true`。

#### Scenario: 商品数组与示例标记
- **WHEN** 解析购物包的 `data/list.json` 与 manifest
- **THEN** `products` 至少有一个对象，每项都有非空的 `title`、`price`、`cover`，数据里的 `sample` 为 `true`，`sampleLabel` 为「示例」，manifest 的 `sample` 为 `true`

### Requirement: 未知意图澄清包
无法识别为 `shopping.browse` 的合法查询 MUST 返回 HTTP 200 的澄清包，MUST NOT 返回 4xx。该包仍 MUST 含有规定的六个文件。manifest 的 `intent` MUST 为 `clarify`，`sample` MUST 为 `false`。`routes.start` MUST 为 `list`。列表页 MUST 通过数据字段 `$message` 展示澄清文案。`data/list.json` 的 `products` MUST 为数组且长度为零，`message` MUST 为非空字符串。列表模版 MUST NOT 包含 `open` 动作，因此 MUST NOT 打开商品详情。详情模版 MUST 仍然存在并通过模版解析，且含有 `back`，但它没有被列表链接。

#### Scenario: 非购物查询得到澄清包
- **WHEN** POST `{"query":"今天星期几"}` 且生成成功
- **THEN** HTTP 200，`intent` 为 `clarify`，`sample` 为 `false`，zip 仍只有规定的六个文件，`start` 为 `list`

#### Scenario: 澄清列表只有说明且没有商品跳转
- **WHEN** 解析该澄清包的列表模版和 `data/list.json`
- **THEN** 列表模版绑定 `$message`，`message` 为非空字符串，`products` 为 `[]`，列表事件中没有 `open`

#### Scenario: 未链接的详情仍可解析
- **WHEN** 解析澄清包的 `templates/detail.json`
- **THEN** 模版解析成功并含有 `back`，同时没有任何来自列表的 `open` 指向 `detail`

### Requirement: 打包前校验
每一份模版 MUST 在打包前用现有模版规则校验。节点 `type` 不为引擎所接受，或 `action` 不是 `open`、`back`、`toast` 时，服务 MUST 拒绝整包，返回 HTTP 422，JSON 含 `code`（值为 `template_invalid`）与非空 `message`，`Content-Type` 为 `application/json`，响应体 MUST NOT 是 zip。

#### Scenario: 未知节点类型返回 422
- **WHEN** 候选模版含有 `type` 为 `button` 的节点
- **THEN** 响应为 HTTP 422，`code` 为 `template_invalid`，正文是 JSON 而不是 zip

#### Scenario: 白名单外动作返回 422
- **WHEN** 候选模版含有 `action` 为 `setText` 或引擎不认识的动作
- **THEN** 响应为 HTTP 422，`code` 为 `template_invalid`，且没有保存新的 zip

### Requirement: 离线内置生成器
当环境变量 `OTTER_LLM_BASE_URL` 未设置时，生成 MUST 使用内置生成器成功完成，MUST NOT 发起出站网络请求，并且仍 MUST 产出通过校验的有效包。内置生成器写出的购物商品 MUST 标记为「示例」。自动化测试 MUST NOT 依赖网络。

#### Scenario: 无模型地址时离线生成购物包
- **WHEN** `OTTER_LLM_BASE_URL` 未设置，且 POST `{"query":"手机壳"}`
- **THEN** 在无出站网络的情况下返回 HTTP 200，`intent` 为 `shopping.browse`，包通过签名与模版校验，商品数据的 `sampleLabel` 为「示例」

#### Scenario: 测试不访问网络
- **WHEN** 在禁止出站网络且未设置 `OTTER_LLM_BASE_URL` 的环境运行生成测试
- **THEN** 生成测试能够成功完成，并且不需要模型服务

### Requirement: 审计日志
每一次成功生成 MUST 写一条审计日志，其中包含本次 `query`、`intent`、bundle `id` 与 `hash`。该条日志 MUST NOT 包含模版文件或数据文件的正文。

#### Scenario: 成功生成留下一条审计
- **WHEN** `手机壳` 生成成功
- **THEN** 有一条日志同时包含该查询原文、`shopping.browse`、返回的 `id`，以及 manifest 中的 `hash`

#### Scenario: 日志不含模版正文
- **WHEN** 检查这次成功生成的审计日志
- **THEN** 日志中没有 `templates/list.json` 或 `templates/detail.json` 的文件正文

### Requirement: 按标识下载
服务 MUST 提供 `GET /api/v1/bundles/{id}`。`id` 来自成功的生成响应。该接口 MUST 返回 HTTP 200，`Content-Type` 为 `application/zip`，正文是该 id 对应的签名 zip，且 zip 内 manifest 的 `id` 与路径中的 id 一致。

#### Scenario: 用生成结果里的 id 下载到同一个包
- **WHEN** `POST /api/v1/generate` 成功并返回 `id`
- **THEN** `GET /api/v1/bundles/{id}` 返回 HTTP 200 的 `application/zip`，解出的 manifest.`id` 等于该 `id`
