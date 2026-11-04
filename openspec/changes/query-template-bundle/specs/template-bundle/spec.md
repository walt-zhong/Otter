## ADDED Requirements

### Requirement: 六文件闭合清单
模版包 MUST 是一个 zip，条目 MUST 恰好为 `manifest.json`、`routes.json`、`templates/list.json`、`templates/detail.json`、`data/list.json`、`data/detail.json` 这六个。MUST NOT 包含目录项、重复条目或任何其他条目。

#### Scenario: 购物包只有这六个条目
- **WHEN** 产出一份有效的 `shopping.browse` 模版包并列出 zip 中央目录
- **THEN** 条目名集合恰好是上述六个路径，且没有目录项、重复项或其他文件

#### Scenario: 多一个条目即整包无效
- **WHEN** zip 在六个允许文件之外还包含任意条目
- **THEN** 该包 MUST 被拒绝，消费者 MUST NOT 解压或渲染其中任何页面

### Requirement: 条目名与危险路径
每个条目名 MUST 与白名单字符串完全一致，使用正斜杠且相对 zip 根。消费者 MUST 拒绝含 `..` 路径段、绝对路径、反斜杠、白名单外的名字，以及目录、符号链接或带 Unix 执行位的条目。

#### Scenario: 路径穿越被拒绝
- **WHEN** 条目名为 `../manifest.json`、`/manifest.json`、`templates/../../data/list.json` 或 `templates\\list.json`
- **THEN** 该包 MUST 被拒绝，对应字节 MUST NOT 被写到目标目录

#### Scenario: 可执行条目被拒绝
- **WHEN** 白名单外的 `evil.exe` 出现在包内，或某个白名单条目带有 Unix 执行位
- **THEN** 该包 MUST 被拒绝，消费者 MUST NOT 把它当作模版执行或渲染

### Requirement: 不压缩与体积上限
每个 zip 条目 MUST 使用 store 方法（压缩方法 0，不压缩）。每个条目的未压缩字节数 MUST 小于或等于 256 KiB（262144 字节）。六个条目的未压缩字节数之和 MUST 小于或等于 1 MiB（1048576 字节）。超出上限或使用压缩的包 MUST 被拒绝。

#### Scenario: 压缩条目被拒绝
- **WHEN** 任一条目的压缩方法不是 0
- **THEN** 生产者 MUST NOT 将其作为有效包发布，消费者 MUST 拒绝整包

#### Scenario: 单文件或总体积超限被拒绝
- **WHEN** 任一文件大于 262144 字节，或六个文件未压缩长度之和大于 1048576 字节
- **THEN** 该包 MUST 被拒绝，且 MUST NOT 渲染

### Requirement: manifest 必填字段
`manifest.json` MUST 是 JSON 对象，且键 MUST 恰好为 `id`、`intent`、`sample`、`createdAt`、`hash`、`alg`、`signature`。`id` MUST 是不含 `/` 与 `..` 的非空字符串。`intent` MUST 是字符串。`sample` MUST 是 JSON 布尔值。`createdAt` MUST 是带时间与时区的 RFC3339 日期时间。`hash` MUST 是 64 位小写十六进制 SHA-256。`alg` MUST 恰好为 `ed25519`。`signature` MUST 是标准 base64（含填充）字符串。

#### Scenario: 字段齐全且类型正确
- **WHEN** 解析一份有效包的 `manifest.json`
- **THEN** 七个键全部存在且类型符合上述约束，`sample` 不是字符串，`alg` 等于 `ed25519`

#### Scenario: 缺字段或算法不符
- **WHEN** manifest 缺少上述任一键，`createdAt` 只是日期，`hash` 不是 64 位小写十六进制，或 `alg` 不是 `ed25519`
- **THEN** 该包 MUST 被拒绝

### Requirement: 五文件规范哈希
`hash` MUST 是对除 manifest 以外的五个文件按固定顺序计算的 SHA-256，顺序为 `routes.json`、`templates/list.json`、`templates/detail.json`、`data/list.json`、`data/detail.json`。对每个文件，输入依次拼接：该路径的 UTF-8 字节、一个 LF（U+000A）、未压缩字节数的十进制 ASCII（无前导零、无符号）、一个 LF、以及该条目的原始字节。哈希 MUST 覆盖这些原始字节，而不是重新序列化后的 JSON。manifest 本身 MUST NOT 进入哈希输入。

#### Scenario: 摘要与规范拼接一致
- **WHEN** 按上述顺序和拼接规则计算五个内容文件的 SHA-256
- **THEN** manifest 的 `hash` 等于该摘要的 64 位小写十六进制

#### Scenario: 改一个内容字节就对不上
- **WHEN** 五个内容文件中任一字节发生变化，而 manifest 仍保留原来的 `hash`
- **THEN** 重新计算的摘要与 `hash` 不一致，该包 MUST 被拒绝

### Requirement: ed25519 签名与整包拒绝
`signature` MUST 是对哈希原始 32 字节摘要（不是十六进制字符串）的 ed25519 签名，再做标准 base64 编码。校验方 MUST 重新计算内容摘要、与 `hash` 比较，并用公钥验证该签名。摘要不符、签名无效、或签名签的是十六进制字符串时，MUST 拒绝整包，MUST NOT 渲染任何页面。

#### Scenario: 对原始摘要的签名通过
- **WHEN** 用与打包方成对的公钥验证 `signature`，被签名消息是 32 字节原始摘要
- **THEN** 摘要与 `hash` 一致且签名有效时，包才可以被继续解析

#### Scenario: 签十六进制字符串必须失败
- **WHEN** `signature` 是对 `hash` 的十六进制 ASCII 文本的合法 ed25519 签名，而不是对 32 字节原始摘要的签名
- **THEN** 校验 MUST 失败，整包 MUST 被拒绝且 MUST NOT 渲染

#### Scenario: 校验失败不渲染局部页面
- **WHEN** 签名或摘要校验失败
- **THEN** 消费者 MUST 丢弃整包，MUST NOT 渲染 list 或 detail

### Requirement: routes 结构
`routes.json` 根对象的键 MUST 恰好为 `start` 与 `pages`。`start` MUST 是 `pages` 中存在的页面名。每个页面对象的键 MUST 恰好为 `template` 与 `data`，两者都是相对 zip 根的路径。`shopping.browse` 包的 `start` MUST 为 `list`，`pages` 的键 MUST 恰好为 `list` 与 `detail`。`list` MUST 指向 `templates/list.json` 与 `data/list.json`。`detail` MUST 指向 `templates/detail.json` 与 `data/detail.json`。

#### Scenario: 购物页面图固定
- **WHEN** manifest 的 `intent` 为 `shopping.browse` 并解析 `routes.json`
- **THEN** `start` 为 `list`，页面只有 `list` 与 `detail`，且模版和数据路径如上

#### Scenario: 多余的根键或页面名无效
- **WHEN** `routes.json` 含有 `start` 与 `pages` 以外的根键，或 `shopping.browse` 包出现 `list` 与 `detail` 以外的页面名
- **THEN** 该包 MUST 被拒绝

### Requirement: 模版与数据分离
每份模版 JSON 根对象 MUST 包含 `layout`，且 MUST NOT 含有 `layout` 与 `events` 以外的键。页面数据 MUST 放在对应的 `data/*.json`，MUST NOT 嵌在模版文件里。模版引用数据时 MUST 使用 `$` 加字段名，例如 `$title` 与 `$price`。商品价格 MUST 放在数据 JSON 的 `price` 字段中，并由模版的 `$price` 绑定展示。

#### Scenario: 模版根上没有数据对象
- **WHEN** 解析 `templates/list.json` 或 `templates/detail.json`
- **THEN** 根上只有 `layout`，以及在存在动作时的 `events`，没有商品数组或价格字面量字段

#### Scenario: 价格来自数据绑定
- **WHEN** 渲染购物列表项或详情中的价格
- **THEN** 模版含有 `$price`，展示出的价格等于数据里该商品的 `price`

### Requirement: 动作白名单
本变更产出的模版里，事件的 `action` MUST 只使用 `open`、`back` 或 `toast`。出现任何其他动作（包括引擎认识但不在此列的动作，以及引擎不认识的动作）时，该包 MUST 无效，消费者 MUST NOT 渲染它。

#### Scenario: 三种动作可以出现在有效包中
- **WHEN** 模版事件的 `action` 全部是 `open`、`back` 或 `toast`
- **THEN** 动作白名单不因此拒绝该包

#### Scenario: 白名单外的动作使整包无效
- **WHEN** 任一事件的 `action` 为 `setText`、`host`、`replace` 或其他不是 `open`、`back`、`toast` 的值
- **THEN** 该包 MUST 被拒绝，且 MUST NOT 渲染
