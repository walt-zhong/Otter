## ADDED Requirements

### Requirement: 调试页提交并同机渲染
Demo 的 debug 构建 MUST 提供调试页，页上有查询输入和提交操作。用户提交后，该页 MUST 在同一台设备上请求生成接口并渲染返回的模版包。打开调试页本身 MUST NOT 要求先完成一次生成请求。

#### Scenario: 调试页可以输入并提交
- **WHEN** 安装并打开 Demo 的 debug 构建，进入调试页
- **THEN** 页面上有查询输入和提交操作，且此时尚未渲染生成包

#### Scenario: 成功后在本机渲染
- **WHEN** 用户在调试页提交 `手机壳` 且生成成功
- **THEN** 同一台设备上的该调试流程渲染返回的包，起始页为列表

### Requirement: 公钥验签先于解压
客户端 MUST 使用打进调试包的 ed25519 公钥校验签名，MUST NOT 从网络获取公钥。在把任何条目写入应用缓存目录之前，客户端 MUST 对照五个内容文件的原始摘要完成验签。签名或摘要失败时，MUST NOT 把条目写入缓存，MUST 显示错误，MUST NOT 渲染。

#### Scenario: 有效签名后才允许写入缓存
- **WHEN** 返回的 zip 用配对私钥对 32 字节原始摘要签名，且摘要与内容一致
- **THEN** 客户端在验签通过之后才把允许的条目写入应用缓存目录

#### Scenario: 验签失败不落盘不渲染
- **WHEN** 签名无效、公钥不匹配，或签名覆盖的是哈希十六进制文本而不是 32 字节摘要
- **THEN** 调试页显示错误，缓存目录中没有该包解压出的模版，并且没有渲染列表或详情

### Requirement: 白名单解压与失败不渲染
解压时 MUST 只把六个白名单文件写入应用缓存目录：`manifest.json`、`routes.json`、`templates/list.json`、`templates/detail.json`、`data/list.json`、`data/detail.json`。出现额外条目、`..`、绝对路径、压缩条目、超限体积，或模版解析失败时，客户端 MUST 拒绝整包，显示错误，并且 MUST NOT 渲染。渲染所用的模版和数据 MUST 来自该缓存目录中 routes 指向的路径。

#### Scenario: 只解压白名单文件
- **WHEN** 包通过验签且条目恰好是六个白名单文件
- **THEN** 应用缓存目录中出现这六个相对路径，渲染从这些路径读取模版和数据

#### Scenario: 额外文件或解析失败不渲染
- **WHEN** zip 含有白名单外条目，或签名有效但模版 JSON 无法按现有规则解析
- **THEN** 调试页显示错误，并且不渲染该包的页面

### Requirement: 页面栈从列表到详情再返回
调试渲染 MUST 使用现有 PageStack 语义。起始页 MUST 是 `list`。列表项打开详情时 MUST 把该商品的 `title`、`price`、`cover` 作为参数压入 `detail`。返回 MUST 回到打开详情之前的 `list`，且列表仍显示原来的商品数据。

#### Scenario: 从列表进入详情
- **WHEN** 购物包渲染出列表后，用户点击其中一项
- **THEN** 页面栈打开 `detail`，详情展示该项的标题、价格和封面

#### Scenario: 返回后仍是原来的列表
- **WHEN** 用户在详情执行返回
- **THEN** 页面回到 `list`，商品列表与打开详情前一致

### Requirement: 示例文案来自数据
当包是示例商品包时，渲染出的列表 MUST 显示数据文件中的 `sampleLabel`。该文案 MUST 来自 `data/list.json` 的 `sampleLabel`，购物示例包中这个值是「示例」。

#### Scenario: 示例包显示数据里的示例
- **WHEN** 渲染 `sample` 为 `true` 且 `sampleLabel` 为「示例」的购物包
- **THEN** 列表界面显示「示例」，且该字符串来自 `data/list.json` 的 `sampleLabel`

### Requirement: 调试源集隔离
该调试页的源文件与清单注册 MUST 只位于 Demo 模块的 `src/debug`。`src/main` 与 `src/release` MUST NOT 包含该调试页，正式变体合并后的清单 MUST NOT 注册它。

#### Scenario: 正式源集没有调试页
- **WHEN** 检查 Demo 的 `src/main`、`src/release` 与正式变体合并清单
- **THEN** 其中没有该查询调试页的源文件或组件注册

#### Scenario: 调试构建含有调试页
- **WHEN** 构建 Demo 的 debug 变体
- **THEN** 调试页来自 `src/debug`，并且用户可以打开它

### Requirement: 正式构建启动不访问网络
正式构建启动原有 Demo 主界面时 MUST NOT 请求 `/api/v1/generate` 或 `/api/v1/bundles/`。无网络时，该启动仍 MUST 能进入原有主界面。正式构建 MUST NOT 在启动时打开查询调试页。

#### Scenario: 正式包冷启动不拉取模版包
- **WHEN** 在无网络环境冷启动 Demo 的 release 构建
- **THEN** 应用进入原有 Demo 主界面，且没有请求生成接口或按 id 下载模版包
