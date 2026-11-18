import { ExpansionCenter } from "../src/expansion"
import { PageStack } from "../src/page-stack"
import { showToast } from "../src/toast"
import type { JsonObject } from "../src/types"
import type { OTEngine } from "../src/engine"

const names = ["pay", "setQty", "removeLine", "refreshStatus", "call", "filter", "openTab"]

export async function openMarket(
  host: HTMLElement,
  engine: OTEngine,
  loadText: (path: string) => Promise<string>,
  openTab: (page: string) => void
): Promise<() => void> {
  const shops = await readShops(loadText)
  const stacks: PageStack[] = []
  const home = await mount("templates/market/routes.json", false)
  const orders = await mount("templates/market/routes-orders.json", true)
  const mine = await mount("templates/market/routes-mine.json", true)
  stacks.push(home, orders, mine)
  home.activate()

  ExpansionCenter.registerHostAction("pay", (params) => {
    const stack = PageStack.current
    if (stack) confirmPay(host, stack, text(params, "amount"))
  })
  ExpansionCenter.registerHostAction("setQty", (params) => {
    const stack = PageStack.current
    if (stack) changeQty(stack, params)
  })
  ExpansionCenter.registerHostAction("removeLine", (params) => {
    const stack = PageStack.current
    if (stack) removeLine(stack, text(params, "lineId"))
  })
  ExpansionCenter.registerHostAction("refreshStatus", () => {
    const stack = PageStack.current
    if (stack) refreshStatus(stack)
  })
  ExpansionCenter.registerHostAction("call", (params) => callShop(text(params, "phone")))
  ExpansionCenter.registerHostAction("filter", (params) => {
    const stack = PageStack.current
    if (stack) filter(stack, shops, text(params, "query"))
  })
  ExpansionCenter.registerHostAction("openTab", (params) => openTab(text(params, "page")))

  return () => {
    for (const name of names) ExpansionCenter.unregisterHostAction(name)
    for (const stack of stacks) stack.release()
  }

  async function mount(route: string, hidden: boolean): Promise<PageStack> {
    const pane = document.createElement("div")
    pane.className = hidden ? "stage is-hidden" : "stage"
    host.appendChild(pane)
    const stack = await engine.stack({
      container: pane,
      routeText: await loadText(route),
      loadText,
    })
    pane.dataset.tab = route.includes("orders") ? "orders" : route.includes("mine") ? "mine" : "home"
    return stack
  }
}

export function selectMarketTab(host: HTMLElement, page: string) {
  const name = page === "orders" || page === "mine" ? page : "home"
  for (const pane of host.querySelectorAll<HTMLElement>(".stage")) {
    const selected = pane.dataset.tab === name
    pane.classList.toggle("is-hidden", !selected)
    if (selected) PageStack.find(pane)?.activate()
  }
}

async function readShops(loadText: (path: string) => Promise<string>): Promise<JsonObject[]> {
  const data = JSON.parse(await loadText("templates/market/mock-data/home.json")) as JsonObject
  return Array.isArray(data.shops) ? data.shops.filter(isObject) : []
}

function confirmPay(host: HTMLElement, stack: PageStack, amount: string) {
  const mask = document.createElement("div")
  mask.className = "pay"
  mask.innerHTML = `<div><strong>确认支付</strong><p></p><div class="row"><button type="button" data-cancel>取消</button><button type="button" class="ok" data-ok>确认</button></div></div>`
  mask.querySelector("p")!.textContent = amount
  mask.querySelector<HTMLButtonElement>("[data-cancel]")!.onclick = () => mask.remove()
  mask.querySelector<HTMLButtonElement>("[data-ok]")!.onclick = () => {
    mask.remove()
    const tail = String(Date.now() % 1000000).padStart(6, "0")
    void stack.replace("result", { orderNo: `NS${tail}`, amount }, null, {})
  }
  host.appendChild(mask)
}

function changeQty(stack: PageStack, params: JsonObject | undefined) {
  const lineId = text(params, "lineId")
  const qty = parseQty(text(params, "qty"))
  if (!lineId || qty == null) return
  stack.editCurrentData((data) => {
    const lines = Array.isArray(data.lines) ? data.lines.filter(isObject) : []
    for (const line of lines) {
      if (line.lineId === lineId) {
        applyQty(line, qty)
        break
      }
    }
    writeTotal(data, lines)
  })
  stack.rebindCurrent()
}

function removeLine(stack: PageStack, lineId: string) {
  if (!lineId) return
  stack.editCurrentData((data) => {
    const lines = (Array.isArray(data.lines) ? data.lines.filter(isObject) : []).filter((line) => line.lineId !== lineId)
    data.lines = lines
    writeTotal(data, lines)
  })
  stack.rebindCurrent()
}

function refreshStatus(stack: PageStack) {
  stack.editCurrentData((data) => {
    const orders = Array.isArray(data.orders) ? data.orders.filter(isObject) : []
    const first = orders[0]
    if (first?.status === "制作中") {
      first.status = "可取餐"
      first.statusNote = "可以到柜台取了，手冲还是热的。"
    }
  })
  stack.rebindCurrent()
  showToast("订单状态已更新")
}

function callShop(phone: string) {
  if (!/^[0-9+()\- ]{6,20}$/.test(phone)) {
    showToast("这个号码不能拨")
    return
  }
  showToast(`正在联系店铺 ${phone}`)
}

function filter(stack: PageStack, shops: JsonObject[], query: string) {
  const needle = query.trim()
  stack.editCurrentData((data) => {
    const filtered = shops.filter((shop) => needle === "" || String(shop.name ?? "").includes(needle))
    data.shops = filtered.map((shop) => structuredClone(shop))
    data.query = needle
    data.noResult = needle !== "" && filtered.length === 0
  })
  stack.rebindCurrent()
}

function applyQty(line: JsonObject, qty: number) {
  const safe = Math.max(1, Math.trunc(qty))
  const price = Number(line.price ?? 0)
  line.qty = safe
  line.qtyText = String(safe)
  line.qtyMinus = String(safe > 1 ? safe - 1 : 1)
  line.qtyPlus = String(safe + 1)
  line.amount = String(price * safe)
}

function writeTotal(data: JsonObject, lines: JsonObject[]) {
  const total = lines.reduce((sum, line) => sum + Number(line.price ?? 0) * Number(line.qty ?? 0), 0)
  data.total = String(total)
  data.totalLabel = `${total} 元`
  data.empty = lines.length === 0
}

function parseQty(raw: string): number | null {
  const value = raw.trim()
  if (!value) return null
  const whole = Number(value)
  if (!Number.isFinite(whole)) return null
  return Math.trunc(whole)
}

function text(params: JsonObject | undefined, key: string): string {
  const value = params?.[key]
  return value == null ? "" : String(value)
}

function isObject(value: unknown): value is JsonObject {
  return value != null && typeof value === "object" && !Array.isArray(value)
}
