import "../demo/styles.css"
import { sections, findEntry } from "./catalog"
import { openMarket, selectMarketTab } from "./market"
import { attachPlayer } from "./player"
import { OTEngine, parseData, PageStack, PermissionCenter, permissionPrompts, BundleCenter, browserCache, publishAll } from "../src/index"
import type { PermissionPrompt } from "../src/permission"

const engine = new OTEngine({ assetBase: "/client" })
const app = document.querySelector<HTMLElement>("#app")!
let release: (() => void) | null = null
let back: (() => void) | null = null
let ticket = 0

const nanshiPrompts: Record<string, PermissionPrompt> = {
  camera: { title: "拍菜单", message: "南市想用相机，拍下黑板上的字。这次只确认允不允许，还不会打开相机。" },
  microphone: { title: "留一句", message: "南市想用麦克风，留一句给店员。这次只确认允不允许，还不会录音。" },
  "location.whenInUse": {
    title: "走到巷口",
    message: "只在你查看南市时使用位置，用来判断你在不在这条巷。不会在后台定位。你可以只给大致位置。",
  },
  photos: { title: "换头像", message: "从相册选一张做头像。只会拿到你点中的那张，不会读取整个相册。" },
  notifications: { title: "取餐通知", message: "摊位做好了就通知你。接下来会弹出系统对话框，你可以拒绝。" },
}

window.addEventListener("hashchange", () => {
  void render()
})
void render()

async function render() {
  const mine = ++ticket
  release?.()
  release = null
  back = null
  const page = location.hash.replace(/^#\/?/, "") || "home"
  app.replaceChildren()
  if (page === "home") {
    paintHome()
    return
  }
  const entry = findEntry(page)
  if (!entry) {
    paintHome()
    return
  }
  const bar = topBar(entry.title, () => back?.() ?? go("home"))
  const body = document.createElement("div")
  body.className = "stage"
  app.append(bar, body)
  if (page === "market") {
    body.classList.add("market")
    const tabs = tabBar()
    app.append(tabs)
    PermissionCenter.install(nanshiPrompts)
    const stop = await openMarket(body, engine, loadText, (name) => {
      selectMarketTab(body, name)
      markTab(tabs, name)
      if (name === "mine") void publishAll()
    })
    if (mine !== ticket) {
      stop()
      return
    }
    release = stop
    back = () => {
      const stack = PageStack.current
      if (stack && stack.depth > 1) {
        stack.back(undefined)
        return
      }
      const selected = tabs.querySelector("button.selected")?.getAttribute("data-tab")
      if (selected && selected !== "home") {
        selectMarketTab(body, "home")
        markTab(tabs, "home")
        return
      }
      go("home")
    }
    return
  }
  if (page === "permission" || page === "stack") {
    if (page === "permission") PermissionCenter.install(permissionPrompts())
    const route = page === "permission" ? "templates/permission/routes.json" : "templates/stack/routes.json"
    const stack = await engine.stack({
      container: body,
      routeText: await loadText(route),
      loadText,
      onFinish: () => go("home"),
    })
    if (mine !== ticket) {
      stack.release()
      return
    }
    stack.activate()
    release = () => stack.release()
    back = () => {
      if (!stack.back(undefined)) go("home")
    }
    return
  }
  if (page === "bundle") {
    release = openGenerate(body)
    back = () => go("home")
    return
  }
  if (!entry.template || !entry.data) return
  const view = engine.show(body, await loadText(entry.template), parseData(await loadText(entry.data)), () => go("home"))
  if (page === "player") {
    const stopPlayer = attachPlayer(view)
    release = () => {
      stopPlayer()
      view.release()
    }
  } else {
    release = () => view.release()
  }
  back = () => go("home")
}

function paintHome() {
  const bar = topBar("Otter", null)
  const nav = document.createElement("div")
  nav.className = "nav stage"
  for (const section of sections) {
    const title = document.createElement("h2")
    title.textContent = section.title
    nav.appendChild(title)
    for (const entry of section.entries) {
      const card = document.createElement("button")
      card.className = "card"
      card.innerHTML = `<div class="row"><strong></strong><em></em></div><p></p>`
      card.querySelector("strong")!.textContent = entry.title
      card.querySelector("em")!.textContent = entry.tag
      card.querySelector("p")!.textContent = entry.desc
      card.onclick = () => go(entry.page)
      nav.appendChild(card)
    }
  }
  app.append(bar, nav)
}

function topBar(title: string, onBack: (() => void) | null): HTMLElement {
  const bar = document.createElement("div")
  bar.className = "topbar"
  if (onBack) {
    const button = document.createElement("button")
    button.type = "button"
    button.textContent = "‹"
    button.setAttribute("aria-label", "返回")
    button.onclick = onBack
    bar.appendChild(button)
  } else {
    const spacer = document.createElement("div")
    spacer.className = "spacer"
    bar.appendChild(spacer)
  }
  const heading = document.createElement("h1")
  heading.textContent = title
  bar.appendChild(heading)
  return bar
}

function tabBar(): HTMLElement {
  const tabs = document.createElement("div")
  tabs.className = "tabs"
  for (const [name, label] of [
    ["home", "首页"],
    ["orders", "订单"],
    ["mine", "我的"],
  ] as const) {
    const button = document.createElement("button")
    button.type = "button"
    button.dataset.tab = name
    button.innerHTML = `${label}<i></i>`
    if (name === "home") button.classList.add("selected")
    button.onclick = () => {
      const host = app.querySelector<HTMLElement>(".market")
      if (!host) return
      selectMarketTab(host, name)
      markTab(tabs, name)
      if (name === "mine") void publishAll()
    }
    tabs.appendChild(button)
  }
  return tabs
}

function markTab(tabs: HTMLElement, page: string) {
  const name = page === "orders" || page === "mine" ? page : "home"
  for (const button of tabs.querySelectorAll("button")) {
    button.classList.toggle("selected", button.dataset.tab === name)
  }
}

function openGenerate(body: HTMLElement): () => void {
  body.innerHTML = `
    <form class="generate">
      <div class="card">
        <p class="eyebrow">想看什么</p>
        <textarea name="query" maxlength="200">买个手机壳</textarea>
        <input name="base" value="http://127.0.0.1:8080" aria-label="服务地址" />
        <button type="submit">生成</button>
        <span class="status"></span>
      </div>
      <div class="label">渲染</div>
      <div class="board"><div class="placeholder">生成后的页面出现在这里</div></div>
    </form>`
  const form = body.querySelector("form")!
  const status = body.querySelector<HTMLElement>(".status")!
  const board = body.querySelector<HTMLElement>(".board")!
  const placeholder = body.querySelector<HTMLElement>(".placeholder")!
  let stack: PageStack | null = null
  let source = ""
  form.onsubmit = async (event) => {
    event.preventDefault()
    const data = new FormData(form)
    const query = String(data.get("query") ?? "").trim()
    const base = String(data.get("base") ?? "").trim().replace(/\/$/, "")
    if (!query || query.length > 200) {
      setStatus("请输入 1 到 200 个字", true)
      return
    }
    setStatus("正在生成", false)
    try {
      const key = new Uint8Array(await (await fetch("/client/raw/otter_dev_public.bin")).arrayBuffer())
      const ready = await BundleCenter.load(browserCache(), "debug", key, async () => {
        const meta = await postJson(api(base, "/api/v1/generate"), { query })
        source = String(meta.source ?? "")
        const id = String(meta.id ?? "")
        const zip = new Uint8Array(await (await fetch(api(base, `/api/v1/bundles/${id}`))).arrayBuffer())
        return { id, zip, intent: String(meta.intent ?? ""), sample: Boolean(meta.sample) }
      }, "NONE")
      stack?.release()
      board.querySelector(".otter-stage")?.remove()
      const pane = document.createElement("div")
      pane.className = "stage"
      pane.style.position = "absolute"
      pane.style.inset = "0"
      board.appendChild(pane)
      placeholder.style.display = "none"
      stack = await engine.stack({
        container: pane,
        routeText: ready.files["routes.json"],
        loadText: async (file) => ready.files[file] ?? loadText(file),
        files: ready.files,
      })
      stack.activate()
      const parts = [source === "model" ? "模型" : source === "offline" ? "离线" : "", ready.intent, ready.sample ? "示例" : ""].filter(Boolean)
      setStatus(parts.join(" · ") || ready.id, ready.fellBack)
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "请求失败", true)
    }
  }
  return () => stack?.release()

  function setStatus(message: string, error: boolean) {
    status.textContent = message
    status.classList.add("show")
    status.classList.toggle("error", error)
  }
}

async function postJson(url: string, body: unknown): Promise<Record<string, unknown>> {
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  })
  if (!response.ok) throw new Error(await readError(response))
  return (await response.json()) as Record<string, unknown>
}

async function readError(response: Response): Promise<string> {
  try {
    const body = (await response.json()) as { message?: string }
    return body.message || `请求失败 ${response.status}`
  } catch {
    return `请求失败 ${response.status}`
  }
}

function api(base: string, path: string): string {
  if (base === "http://127.0.0.1:8080" || base === "http://localhost:8080") return path
  return `${base}${path}`
}

async function loadText(path: string): Promise<string> {
  const response = await fetch(`/client/${path}`)
  if (!response.ok) throw new Error(`${path} 读取失败`)
  return response.text()
}

function go(page: string) {
  location.hash = page === "home" ? "#/" : `#/${page}`
}
