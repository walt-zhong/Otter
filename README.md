# Otter

这个目录是一个仓库。四个端并列放在下面，一起提交。

| 目录 | 内容 |
| --- | --- |
| `otter-android` | Android SDK 和 Demo |
| `otter-ios` | iOS SDK 和 Demo |
| `otter-harbor` | Go 服务。query 进来，签名 zip 出去 |
| `otter-studio` | React 调试台。提交 query，查看意图，下载包 |

iOS Demo 的示例模版和图片在 `otter-ios/Demo`。iOS 工程编译 `otter-android` 里的表达式 C++。

协议说明在 `otter-android/docs`：

| 文件 | 作用 |
| --- | --- |
| `render-pipeline.md` | 模版进客户端之后怎么解析、布局、绘制 |
| `sdk-integration.md` | 业务工程怎么把 SDK 接进页面 |
| `template-format.md` | 写或生成模版时的 JSON 格式 |
| `node-types.md` | 十二种节点的字段 |
| `demo-guide.md` | Demo 页面目录，以及真机调试生成页 |

跨端的 OpenSpec 在 `openspec/`。
