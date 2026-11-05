# otter-harbor

Otter 的后端。收到 query 后识别意图，生成模版和示例数据，打成签名 zip。

```shell
go run ./cmd/ottersrv
```

模版管理后台在并列的 `otter-studio`。`GET /api/v1/bundles` 返回查询、意图和签名信息，不返回模版正文。手机上的调试页在 `otter-android` 的 debug 构建里，导航页的「生成」。手机上的 `127.0.0.1` 是手机自己，USB 连接时先执行 `adb reverse tcp:8080 tcp:8080`，页面地址保持 `http://127.0.0.1:8080`。完整步骤，包括转发失效、模拟器和同一 Wi-Fi，写在 `otter-android` 的 `docs/demo-guide.md`「查询下发」。

没有设置 `OTTER_LLM_API_KEY` 和 `OTTER_LLM_BASE_URL` 时，服务用关键词判断意图，并离线写出示例商品。要让 DeepSeek 判断意图并生成购物模版时：

```shell
export OTTER_LLM_API_KEY=你的密钥
go run ./cmd/ottersrv
```

只给密钥时，地址默认是 `https://api.deepseek.com`，模型默认是 `deepseek-flash`。密钥放在环境变量或本目录的 `.env` 里。`.env` 已被忽略，不要提交，也不要发给手机。进程里已经设置的变量优先于 `.env`。其它兼容接口用 `OTTER_LLM_BASE_URL` 和 `OTTER_LLM_MODEL` 覆盖。澄清意图仍用内置页面。购物模版由模型写，服务端改回固定路由，并强制示例标记。模型失败会重试一次，仍失败就返回 422，不会用离线商品冒充模型结果。

生产换签名密钥时设置 `OTTER_SIGNING_KEY`，值为 64 字节 ed25519 私钥的标准 base64。未设置时使用仓库里的调试密钥，只与 Android 调试包里的公钥成对。
