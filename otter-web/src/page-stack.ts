import { evaluateParams, merge, runEvents, sameOverlay, type PageNavigator } from "./events"
import { parseRoutes, type PageRouteTable } from "./routes"
import { showToast } from "./toast"
import type { Json, JsonObject } from "./types"
import { createTemplateView, fitDensity, type AssetHost, type TemplateView } from "./view"
import type { ParsedTemplate } from "./types"

const CANNOT_OPEN = "这个页面还打不开"
const MAX_DEPTH = 32

export type StackEngine = {
  host: AssetHost
  parse: (template: string) => ParsedTemplate
}

type Frame = {
  name: string
  templatePath: string
  data: JsonObject
  view: TemplateView | null
  slotKey: string | null
  slotIndex: number
}

export type PageStackOptions = {
  container: HTMLElement
  routeText: string
  engine: StackEngine
  loadText: (path: string) => Promise<string>
  files?: Record<string, string>
  onFinish?: () => void
}

export class PageStack {
  static current: PageStack | null = null
  private static live = new Set<PageStack>()

  readonly routes: PageRouteTable
  private stack: Frame[] = []
  private released = false
  private observer: ResizeObserver | null = null
  private pushed = 0
  private ignorePop = false
  private readonly token = `otter-${Math.random().toString(36).slice(2)}`
  private readonly onPopState = () => {
    if (this.ignorePop) {
      this.ignorePop = false
      return
    }
    if (history.state?.otter !== this.token) return
    if (this.stack.length > 1) {
      this.pushed = Math.max(0, this.pushed - 1)
      void this.popFrame(undefined)
    }
  }

  private constructor(
    private readonly container: HTMLElement,
    routes: PageRouteTable,
    private readonly engine: StackEngine,
    private readonly loadText: (path: string) => Promise<string>,
    private readonly files: Record<string, string> | undefined,
    private readonly onFinish: (() => void) | undefined
  ) {
    this.routes = routes
    this.container.classList.add("otter-stage")
    PageStack.live.add(this)
  }

  static async attach(options: PageStackOptions): Promise<PageStack> {
    const routes = parseRoutes(options.routeText)
    const stack = new PageStack(
      options.container,
      routes,
      options.engine,
      options.loadText,
      options.files,
      options.onFinish
    )
    window.addEventListener("popstate", stack.onPopState)
    await stack.waitForSize()
    await stack.open(routes.start, undefined, null, {})
    return stack
  }

  static find(element: Element | null): PageStack | null {
    const stage = element?.closest(".otter-stage")
    if (!(stage instanceof HTMLElement)) return PageStack.current
    for (const stack of PageStack.live) {
      if (stack.container === stage) return stack
    }
    return PageStack.current
  }

  get depth(): number {
    return this.stack.length
  }

  activate() {
    PageStack.current = this
  }

  release() {
    this.released = true
    this.observer?.disconnect()
    window.removeEventListener("popstate", this.onPopState)
    for (const frame of this.stack) frame.view?.release()
    this.stack = []
    this.container.replaceChildren()
    PageStack.live.delete(this)
    if (PageStack.current === this) PageStack.current = null
  }

  async open(page: string, rawParams: JsonObject | undefined, item: JsonObject | null, pageData: JsonObject) {
    if (this.released) return
    if (this.stack.length >= MAX_DEPTH) {
      showToast(CANNOT_OPEN)
      return
    }
    const route = this.routes.pages[page]
    if (!route) {
      showToast(CANNOT_OPEN)
      return
    }
    const current = this.stack.at(-1)
    current?.view?.snapshot()
    const scope = merge(pageData ?? current?.data, item)
    const overlay = rawParams ? evaluateParams(rawParams, scope) : undefined
    if (current && current.name === page && sameOverlay(current.data, overlay)) return
    const shown = await this.materialize(page, route.template, route.data, overlay, item, current?.data)
    if (!shown) return
    this.stack.push(shown)
    if (this.stack.length > 1) {
      history.pushState({ otter: this.token }, "")
      this.pushed += 1
    }
    this.present(shown, true)
  }

  async replace(page: string, rawParams: JsonObject | undefined, item: JsonObject | null, pageData: JsonObject) {
    if (this.released) return
    const route = this.routes.pages[page]
    if (!route) {
      showToast(CANNOT_OPEN)
      return
    }
    const current = this.stack.at(-1)
    current?.view?.snapshot()
    const scope = merge(pageData ?? current?.data, item)
    const overlay = rawParams ? evaluateParams(rawParams, scope) : undefined
    const shown = await this.materialize(page, route.template, route.data, overlay, item, current?.data)
    if (!shown) return
    const removed = this.stack.pop()
    this.stack.push(shown)
    if (removed?.view) {
      removed.view.root.remove()
      removed.view.release()
    }
    this.present(shown, false)
  }

  back(rawParams: JsonObject | undefined): boolean {
    if (this.stack.length <= 1) return false
    if (this.pushed > 0) {
      this.ignorePop = true
      this.pushed -= 1
      history.back()
    }
    void this.popFrame(rawParams)
    return true
  }

  popTo(page: string, rawParams: JsonObject | undefined): boolean {
    let index = -1
    for (let cursor = this.stack.length - 1; cursor >= 0; cursor -= 1) {
      if (this.stack[cursor].name === page) {
        index = cursor
        break
      }
    }
    if (index < 0 || index === this.stack.length - 1) return index >= 0
    const top = this.stack.at(-1)
    top?.view?.snapshot()
    const result = rawParams ? evaluateParams(rawParams, top?.data ?? {}) : undefined
    while (this.stack.length - 1 > index) {
      const leaving = this.stack.pop()
      leaving?.view?.root.remove()
      leaving?.view?.release()
      if (this.pushed > 0) {
        this.ignorePop = true
        this.pushed -= 1
        history.back()
      }
    }
    const revealed = this.stack[index]
    if (result && Object.keys(result).length > 0) {
      Object.assign(revealed.data, result)
      revealed.view?.rebind()
    }
    this.present(revealed, false)
    return true
  }

  editCurrentData(block: (data: JsonObject) => void) {
    const frame = this.stack.at(-1)
    if (!frame) return
    frame.view?.snapshot()
    block(frame.data)
  }

  rebindCurrent() {
    this.stack.at(-1)?.view?.rebind()
  }

  private async popFrame(rawParams: JsonObject | undefined) {
    if (this.stack.length <= 1) return
    const leaving = this.stack.pop()
    if (!leaving) return
    leaving.view?.snapshot()
    const params = rawParams ?? declaredBack(leaving.view)
    const result = params ? evaluateParams(params, leaving.data) : undefined
    const revealed = this.stack.at(-1)
    if (revealed && result && Object.keys(result).length > 0) {
      const bucket = leaving.slotKey ? revealed.data[leaving.slotKey] : undefined
      const item = Array.isArray(bucket) ? bucket[leaving.slotIndex] : undefined
      if (isObject(item)) Object.assign(item, result)
      else Object.assign(revealed.data, result)
      revealed.view?.rebind()
    }
    this.slideOut(leaving)
    if (revealed) this.present(revealed, false)
  }

  private async materialize(
    page: string,
    templatePath: string,
    dataPath: string | null,
    overlay: JsonObject | undefined,
    item: JsonObject | null,
    pageData: JsonObject | undefined
  ): Promise<Frame | null> {
    try {
      const base = dataPath ? parseObject(await this.read(dataPath)) : {}
      const data = merge(base, overlay)
      const template = await this.read(templatePath)
      const parsed = this.engine.parse(template)
      fitDensity(this.engine.host, this.container.clientWidth)
      const size = this.viewport()
      const nav = this.navigator()
      const view = createTemplateView(parsed, data, size, this.engine.host, (names, row) => {
        runEvents(view, names, row, nav)
      })
      const slot = findItem(pageData, item)
      return {
        name: page,
        templatePath,
        data,
        view,
        slotKey: slot?.key ?? null,
        slotIndex: slot?.index ?? -1,
      }
    } catch (error) {
      console.error(error)
      showToast(CANNOT_OPEN)
      return null
    }
  }

  private present(frame: Frame, enter: boolean) {
    const view = frame.view
    if (!view) return
    view.root.style.position = "absolute"
    view.root.style.inset = "0"
    this.container.appendChild(view.root)
    view.relayout(this.viewport())
    if (enter && this.container.clientWidth > 0 && !prefersReducedMotion()) {
      view.root.style.transform = "translateX(100%)"
      view.root.style.transition = "transform 280ms cubic-bezier(0, 0, 0.2, 1)"
      requestAnimationFrame(() => {
        view.root.style.transform = "translateX(0)"
      })
    }
  }

  private slideOut(frame: Frame) {
    const view = frame.view
    if (!view) return
    if (prefersReducedMotion()) {
      view.root.remove()
      view.release()
      return
    }
    view.root.style.transition = "transform 240ms cubic-bezier(0, 0, 0.2, 1)"
    view.root.style.transform = "translateX(100%)"
    window.setTimeout(() => {
      view.root.remove()
      view.release()
    }, 240)
  }

  private navigator(): PageNavigator {
    return {
      open: (page, params, item, data) => {
        void this.open(page, params, item, data)
      },
      replace: (page, params, item, data) => {
        void this.replace(page, params, item, data)
      },
      popTo: (page, params) => this.popTo(page, params),
      back: (params) => this.back(params),
      finish: () => this.onFinish?.(),
    }
  }

  private viewport() {
    return {
      width: this.container.clientWidth,
      height: this.container.clientHeight,
    }
  }

  private async read(path: string): Promise<string> {
    if (this.files && Object.prototype.hasOwnProperty.call(this.files, path)) {
      return this.files[path]
    }
    return this.loadText(path)
  }

  private waitForSize(): Promise<void> {
    if (this.container.clientWidth > 0 && this.container.clientHeight > 0) {
      this.watchSize()
      return Promise.resolve()
    }
    return new Promise((resolve) => {
      const observer = new ResizeObserver(() => {
        if (this.container.clientWidth > 0 && this.container.clientHeight > 0) {
          observer.disconnect()
          this.watchSize()
          resolve()
        }
      })
      observer.observe(this.container)
    })
  }

  private watchSize() {
    this.observer = new ResizeObserver(() => {
      const frame = this.stack.at(-1)
      if (!frame?.view) return
      if (this.container.clientWidth <= 0 || this.container.clientHeight <= 0) return
      frame.view.relayout(this.viewport())
    })
    this.observer.observe(this.container)
  }
}

function declaredBack(view: TemplateView | null): JsonObject | undefined {
  if (!view) return undefined
  const found = Object.values(view.template.events).flatMap((event) => {
    if (event.kind !== "back" || !event.params) return []
    return [event.params]
  })
  return found.length === 1 ? found[0] : undefined
}

function findItem(page: JsonObject | undefined, item: JsonObject | null): { key: string; index: number } | null {
  if (!page || !item) return null
  for (const [key, value] of Object.entries(page)) {
    if (!Array.isArray(value)) continue
    const index = value.indexOf(item)
    if (index >= 0) return { key, index }
  }
  return null
}

function parseObject(text: string): JsonObject {
  const value = JSON.parse(text) as Json
  if (!isObject(value)) throw new Error("数据必须是 JSON 对象")
  return value
}

function isObject(value: unknown): value is JsonObject {
  return value != null && typeof value === "object" && !Array.isArray(value)
}

function prefersReducedMotion(): boolean {
  return window.matchMedia?.("(prefers-reduced-motion: reduce)").matches ?? false
}
