# 文档

| 文档 | 读它的时候 |
| --- | --- |
| [architecture.md](architecture.md) | 看解析、布局、事件和页面栈怎么串 |
| [getting-started.md](getting-started.md) | 把库接进自己的页面 |
| [components.md](components.md) | 写某一种节点 |
| [template-json.md](template-json.md) | 对照生成模版时的字段约定 |
| [demo.md](demo.md) | 找一个能跑的例子 |

项目介绍在仓库根目录的 [README.md](../README.md)。Stretch 和表达式引擎的许可在 [NOTICE](../NOTICE)。

## 公开仓库还缺的文件

- 英文 README 摘要。
- `CONTRIBUTING.md`：怎么跑 `:OTAndroid:testDebugUnitTest`，改字段时同时改解析器和 `template-json.md`。
- Issue、Pull Request 模板。
- `CHANGELOG.md`。
- 安全说明：模版不执行脚本；`host` 名字由宿主登记。
- Maven 坐标。现在只能 `implementation(project(":OTAndroid"))`。
- 模版的 JSON Schema。约束目前在 `TemplateJsonParser` 里。
- 各 Demo 页的截图，以及跑单元测试的 CI。
- iOS、HarmonyOS 的实现边界。权限的能力名和写回字段已经按同一份约定写了，仓库里还没有这两端的代码。

公开入口是 `OTEngine`、`TemplateContext`、`PageStack`、`ExpansionCenter`、`AndroidPermissionCenter`。
