# 文档

从这里进入 Otter。协议字段只维护一份，在 `otter-android/docs`。各端的接入和渲染写在各自目录里。

## 仓库

| 文档 | 内容 |
| --- | --- |
| [architecture.md](architecture.md) | 五个端怎么分工，签名包怎么从服务进到页面 |
| [protocol.md](protocol.md) | 协议索引。字段表指向 Android 文档，不在这里再写一遍 |

## 协议

| 文档 | 内容 |
| --- | --- |
| [otter-android/docs/template-format.md](../otter-android/docs/template-format.md) | 写或生成模版时的 JSON 格式 |
| [otter-android/docs/node-types.md](../otter-android/docs/node-types.md) | 十二种节点的字段 |

## 各端

| 端 | 接入 | 渲染 | Demo |
| --- | --- | --- | --- |
| Android | [sdk-integration.md](../otter-android/docs/sdk-integration.md) | [render-pipeline.md](../otter-android/docs/render-pipeline.md) | [demo-guide.md](../otter-android/docs/demo-guide.md) |
| Web | [sdk-integration.md](../otter-web/docs/sdk-integration.md) | [render-pipeline.md](../otter-web/docs/render-pipeline.md) | [demo-guide.md](../otter-web/docs/demo-guide.md) |
| iOS | [otter-ios/README.md](../otter-ios/README.md) | 同协议，渲染在 iOS 工程里 | `otter-ios/Demo` |

Android SDK 的总述在 [otter-android/README.md](../otter-android/README.md)。Web SDK 的总述在 [otter-web/README.md](../otter-web/README.md)。
