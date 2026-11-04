## ADDED Requirements

### Requirement: 工程位置与技术栈
调试台 MUST 是位于 `server/web` 的 Vite、React 与 TypeScript 应用。浏览器端 MUST 通过该应用提交查询并查看生成结果。

#### Scenario: 工程在 server/web
- **WHEN** 检查调试台工程
- **THEN** 源码位于 `server/web`，并且工程使用 Vite、React 与 TypeScript

### Requirement: 提交查询
用户 MUST 能在页面中输入一条查询并提交。提交时调试台 MUST 把输入原文作为 JSON 字段 `query`，以 `POST /api/v1/generate` 发送。

#### Scenario: 输入并提交
- **WHEN** 用户在输入框键入 `手机壳` 并提交
- **THEN** 调试台向 `/api/v1/generate` 发送 `{"query":"手机壳"}`

### Requirement: 成功结果
生成成功后，界面 MUST 显示响应中的 `intent`。当 `sample` 为 `true` 时，界面 MUST 显示「示例」。当 `sample` 为 `false` 时，界面 MUST NOT 把「示例」显示为该次结果的示例标记。界面 MUST 显示且只显示这六个文件名：`manifest.json`、`routes.json`、`templates/list.json`、`templates/detail.json`、`data/list.json`、`data/detail.json`。

#### Scenario: 购物成功展示意图示例和文件名
- **WHEN** 生成成功且响应的 `intent` 为 `shopping.browse`、`sample` 为 `true`
- **THEN** 界面显示 `shopping.browse`、文字「示例」，以及上述六个文件名，没有第七个文件名

#### Scenario: 澄清结果不显示示例标记
- **WHEN** 生成成功且响应的 `sample` 为 `false`、`intent` 为 `clarify`
- **THEN** 界面显示 `clarify` 和六个文件名，并且不把「示例」显示为示例标记

### Requirement: 下载压缩包
生成成功后，用户 MUST 能从调试台下载该包。下载请求 MUST 是 `GET /api/v1/bundles/{id}`，其中 `id` 是本次成功响应里的 `id`。

#### Scenario: 下载本次生成的 zip
- **WHEN** 生成成功且用户执行下载
- **THEN** 浏览器请求 `GET /api/v1/bundles/{id}`，`id` 等于本次响应的 `id`，并得到该 zip

### Requirement: 失败提示
生成失败时，界面 MUST 显示 API 错误 JSON 中的 `message`。失败后 MUST NOT 把这次失败显示为可下载的新包。

#### Scenario: 展示 422 的错误消息
- **WHEN** `POST /api/v1/generate` 返回 HTTP 422，JSON 的 `message` 为一条非空错误说明
- **THEN** 界面显示该 `message` 的全文，且不为这次失败提供 zip 下载

### Requirement: 开发服务器代理
Vite 开发服务器 MUST 把以 `/api` 开头的请求代理到本地 Go HTTP 服务，并保留路径与方法。调试台 MUST 通过开发服务器源站上的 `/api` 访问后端，而不是由页面直接写死后端端口。

#### Scenario: 提交走开发服务器的 api 前缀
- **WHEN** 用户在 Vite 开发服务器打开的页面上提交查询
- **THEN** 浏览器请求该开发源站的 `/api/v1/generate`，并由 Vite 将该 POST 转发到本地 Go HTTP 服务
