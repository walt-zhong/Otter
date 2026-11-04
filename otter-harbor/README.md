# otter-harbor

Otter 的后端。收到 query 后识别意图，生成模版和示例数据，打成签名 zip。

```shell
go run ./cmd/ottersrv
```

调试台在并列的 `otter-studio`。手机上的调试页在 `otter-android` 的 debug 构建里，导航页的「生成」。手机上的 `127.0.0.1` 是手机自己，USB 连接时先执行 `adb reverse tcp:8080 tcp:8080`，页面地址保持 `http://127.0.0.1:8080`。完整步骤，包括转发失效、模拟器和同一 Wi-Fi，写在 `otter-android` 的 `docs/demo-guide.md`「查询下发」。

没有设置 `OTTER_LLM_BASE_URL` 时，服务离线写出示例商品。生产换签名密钥时设置 `OTTER_SIGNING_KEY`，值为 64 字节 ed25519 私钥的标准 base64。未设置时使用仓库里的调试密钥，只与 Android 调试包里的公钥成对。
