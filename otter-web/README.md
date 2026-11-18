# otter-web

Otter 的 Web 端。JSON 模版在浏览器里画出来，Demo 的页面和 Android Demo 对齐。模版在 `templates/`。

协议字段在 [docs/template-format.md](../otter-android/docs/template-format.md) 和 [docs/node-types.md](../otter-android/docs/node-types.md)。仓库里五个端怎么配合见 [docs/architecture.md](../docs/architecture.md)。

## 文档

| 文档 | 内容 |
| --- | --- |
| [docs/sdk-integration.md](docs/sdk-integration.md) | 业务页怎么接入：画一页、页面栈、权限、签名包 |
| [docs/render-pipeline.md](docs/render-pipeline.md) | 解析、表达式、Yoga 布局、DOM，以及和 Android 的差别 |
| [docs/demo-guide.md](docs/demo-guide.md) | Demo 页面，以及本机怎么打开生成页 |

## 开发

```shell
npm install
npm run dev
```

开发服务器在 `http://127.0.0.1:5174`。`/client/templates` 指向本目录的 `templates/`，图片、Lottie 和调试公钥仍从 `otter-android/Demo` 读取。`/api` 转到 `http://127.0.0.1:8080`。

```shell
npm test
npm run build
```

`npm test` 会解析 `templates/` 里的全部模版和路由。`npm run build` 先做类型检查，再交给 Vite。
