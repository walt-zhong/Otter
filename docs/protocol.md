# 协议索引

模版格式只写在 Android 文档里。改字段时改那里，Web 和 iOS 跟着同一份。

| 要查什么 | 文档 |
| --- | --- |
| 根对象、字段顺序、尺寸、颜色、表达式、事件、路由 | [template-format.md](../otter-android/docs/template-format.md) |
| 十二种节点各自的字段 | [node-types.md](../otter-android/docs/node-types.md) |
| 解析失败时长什么样、Android 上怎么画 | [render-pipeline.md](../otter-android/docs/render-pipeline.md) |
| Web 上同一份 JSON 怎么进 DOM | [render-pipeline.md](../otter-web/docs/render-pipeline.md) |
| 签名 zip 的文件和摘要 | [architecture.md](architecture.md) |

示例 JSON 分三份：Android 在 `otter-android/Demo/src/main/assets/templates/`，Web 在 `otter-web/templates/`，iOS 在 `otter-ios/Demo`。

共同约束：

- 一份模版是 `layout` 加可选的 `events`。未知字段、未知 `type`、指向不存在节点的 `onClick`、`onChange` 或 `target`，解析直接失败。
- 节点最多 2000 个，深度最多 32。`id` 和事件名是 `[A-Za-z_][A-Za-z0-9_]*`。
- 尺寸是数字、`fill` 或 `wrap`。颜色是 `#RGB`、`#RRGGBB`、`#AARRGGBB` 或 `transparent`。
- 以 `$` 开头的字符串是表达式。列表项的展示只用这一项的数据；事件求值时页面数据和列表项合并，同名字段取列表项。
- 表达式求值失败，或结果是 null 时，界面上保留原来的字符串。所以缺字段会显示成 `$title`。
- 页面栈只认 `routes.json` 里的 `start` 和 `pages`。

`env('isWeb')` 是 Web 端追加的环境值，Android 和 iOS 的表达式里不要依赖它。
