## 1. 后端骨架

- [x] 1.1 建立 `server/` Go module `otter/server`，调试 ed25519 密钥与配置加载
- [x] 1.2 实现 zip 摘要、签名、store 打包与六文件校验
- [x] 1.3 实现意图分类、离线购物/澄清生成与模版校验
- [x] 1.4 实现 HTTP API、内存包存储、审计日志与可选模型一次重试

## 2. React 调试台

- [x] 2.1 建立 `server/web` Vite + React + TypeScript，代理 `/api`
- [x] 2.2 查询、意图、示例标记、六个文件名、下载与错误展示

## 3. Android 渲染

- [x] 3.1 `AssetsUtils.readRelative` 与 `OTTemplate.fileRoot`，`PageStack` 从目录读路由和数据
- [x] 3.2 Demo debug 调试页：下载 zip、内置公钥验签、解压并渲染

## 4. 验证

- [x] 4.1 `go test ./...` 覆盖规格场景
- [x] 4.2 React 单元测试与 `OTAndroid` 路径测试通过
