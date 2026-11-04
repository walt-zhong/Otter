## Why

Otter 两端已经能解析同一份窄 JSON，但模版只存在安装包里，模型无法按用户的一句话产出一屏可点击的界面。调试期需要一条从 query 到多页渲染的闭环：后端识别意图、生成模版和示例数据、打包下发，Android 先渲染，iOS 收同一个包。

## What Changes

- 新增单独部署的后端：Go API 做意图识别、模版与示例数据生成、校验、签名和 zip 打包；React 调试台提交 query 并查看意图、示例标记和包内容。
- 新增 `shopping.browse` 意图。页面图固定为 `list` 与 `detail`。模型只改排版，不发明页面名。商品由模型编写，界面标明示例。
- 下发物是一个签名 zip。模版与数据分文件存放。列表点击用 `open` 把当前商品带到详情页。
- Android Demo 增加调试页：输入 query，下载 zip，验签后用页面栈渲染。引擎需要能从包内路径读模版和数据，而不只从 assets 读。
- iOS 使用同一 zip 契约；本变更先保证包格式和校验在后端测通，端上渲染以 Android 为先。
- 网页管理端、真实商品目录、可视化编辑器、灰度发布不在本变更内。意图的页面图、动作表和提示词放在后端配置中。

## Capabilities

### New Capabilities

- `template-bundle`: 签名 zip 的文件布局、manifest、routes、模版与数据分离、大小与路径约束、验签失败不渲染。
- `query-generation`: 调试构建中的 query 入口、意图识别、`shopping.browse` 的两页页面图、示例商品标记、动作白名单、解析失败整包丢弃。
- `debug-console`: React 调试台提交 query、展示意图与示例标记、下载或查看 zip。
- `android-bundle-render`: Android Demo 调试页拉取 zip，验签解压后从列表渲染到详情。

### Modified Capabilities

- 无。仓库尚无已归档的主规格。

## Impact

- 新增 `server/`：Go module 与 React 应用。
- Android：`OTEngine` / `PageStack` 增加从已解压目录读取模版与数据的路径；Demo 增加调试入口。
- 依赖：Go 标准库打包与签名（ed25519）、可选的 OpenAI 兼容模型接口。无密钥时使用内置示例生成器，测试不访问网络。
- 安全：仅 HTTPS、包大小与文件名白名单、私钥签名、公钥验签、解析器二次校验、购物意图仅 `open` / `back` / `toast`。
