# otter-studio

Otter 的调试台。把一句 query 交给旁边的 `otter-harbor`，查看意图、示例标记，并下载 zip。

```shell
npm install
npm run dev
```

开发服务器把 `/api` 转到 `http://127.0.0.1:8080`。先在 `otter-harbor` 里启动 `go run ./cmd/ottersrv`。
