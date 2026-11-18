import { runEvents, type PageNavigator } from "./events"
import { ExpansionCenter } from "./expansion"
import { PageStack, type PageStackOptions } from "./page-stack"
import { parseTemplate } from "./parser"
import { showToast } from "./toast"
import type { JsonObject } from "./types"
import { createTemplateView, fitDensity, type AssetHost, type TemplateView } from "./view"

export type EngineOptions = {
  density?: number
  assetBase?: string
}

export class OTEngine {
  readonly host: AssetHost

  constructor(options: EngineOptions = {}) {
    const base = options.assetBase ?? ""
    const density = options.density ?? 1
    this.host = {
      density,
      densityLocked: options.density != null,
      resolveImage: (src) => resolveImage(src, base),
      resolveLottie: (src) => resolveLottie(src, base),
    }
  }

  show(
    container: HTMLElement,
    template: string,
    data: JsonObject,
    onFinish?: () => void
  ): TemplateView {
    const parsed = parseTemplate(template)
    fitDensity(this.host, container.clientWidth)
    const size = { width: container.clientWidth, height: container.clientHeight }
    const nav = singlePageNav(onFinish)
    const view = createTemplateView(parsed, data, size, this.host, (names, item) => {
      runEvents(view, names, item, nav)
    })
    container.classList.add("otter-stage")
    container.replaceChildren(view.root)
    const place = () => {
      if (container.clientWidth <= 0 || container.clientHeight <= 0) return
      view.relayout({ width: container.clientWidth, height: container.clientHeight })
    }
    place()
    requestAnimationFrame(place)
    const observer = new ResizeObserver(() => {
      if (container.clientWidth <= 0 || container.clientHeight <= 0) return
      view.relayout({ width: container.clientWidth, height: container.clientHeight })
    })
    observer.observe(container)
    const release = view.release.bind(view)
    view.release = () => {
      observer.disconnect()
      release()
    }
    return view
  }

  stack(options: Omit<PageStackOptions, "engine">): Promise<PageStack> {
    return PageStack.attach({ ...options, engine: { host: this.host, parse: parseTemplate } })
  }
}

function singlePageNav(onFinish?: () => void): PageNavigator {
  return {
    open(page) {
      if (!page || !ExpansionCenter.pageOpener) {
        showToast("这个页面还打不开")
        return
      }
      ExpansionCenter.pageOpener(page)
    },
    replace() {
      showToast("这个页面还打不开")
    },
    popTo() {
      return false
    },
    back() {
      return false
    },
    finish() {
      onFinish?.()
    },
  }
}

export function resolveImage(src: string, base: string): string {
  if (!src) return src
  if (/^(https?:|blob:|data:|content:)/.test(src)) return src
  if (src.startsWith("res:")) {
    const name = src.slice(4)
    if (!base) return src
    if (name === "glass_wallpaper") return `${base}/res/glass_wallpaper.jpg`
    return `${base}/res/${name}.svg`
  }
  return src
}

export function resolveLottie(src: string, base: string): string {
  if (/^https?:/.test(src)) return src
  if (src.startsWith("assets:")) {
    const file = src.slice("assets:".length).replace(/^\//, "")
    return `${base}/${file}.json`
  }
  return src
}

export function parseData(text: string): JsonObject {
  const value = JSON.parse(text) as unknown
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("数据必须是 JSON 对象")
  }
  return value as JsonObject
}
