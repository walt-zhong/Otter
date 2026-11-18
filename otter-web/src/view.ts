import { mountGlass } from "./glass"
import "./sdk.css"
import { cssBackground, cssColor } from "./color"
import { displayValue, getResult, isExpression } from "./expression"
import {
  layoutItem,
  layoutTree,
  type Edges,
  type LayoutBox,
  type LayoutNode,
} from "./layout"
import { fontWeightValue, lineBox } from "./measure"
import type { Json, JsonObject, ParsedNode, ParsedTemplate, ViewPort } from "./types"

export type AssetHost = {
  density: number
  densityLocked?: boolean
  resolveImage: (src: string) => string
  resolveLottie: (src: string) => string
}

export function designScale(windowWidth: number): number {
  if (!(windowWidth > 0)) return 1
  return Math.max(0.88, Math.min(windowWidth, 480) / 375)
}

export function fitDensity(host: AssetHost, windowWidth: number): void {
  if (host.densityLocked || !(windowWidth > 0)) return
  host.density = designScale(windowWidth)
}

export type TemplateView = {
  root: HTMLElement
  data: JsonObject
  template: ParsedTemplate
  relayout: (viewport: ViewPort) => void
  rebind: () => void
  release: () => void
  element: (id: string) => HTMLElement | undefined
  snapshot: () => void
  setText: (id: string, value: string, item: JsonObject | null) => void
  setTextStyle: (
    id: string,
    patch: { fontSize?: string; color?: string; text?: string },
    scope: JsonObject | null
  ) => void
  setChecked: (ids: string[], value: string, scope: JsonObject | null) => void
  readControl: (id: string) => string
  listItems: (id: string) => JsonObject[]
  patchListItem: (id: string, index: number, patch: Record<string, string>) => void
  setProgress: (id: string, fraction: number) => void
  setImage: (id: string, src: string) => void
  setLottiePlaying: (id: string, playing: boolean) => void
}

type ItemRecord = { item: JsonObject }

const itemsOf = new WeakMap<HTMLElement, ItemRecord>()
const textOverride = new WeakMap<HTMLElement, string>()
const imageOverride = new WeakMap<HTMLElement, string>()
const lottieOf = new WeakMap<HTMLElement, { play: () => void; pause: () => void; destroy: () => void }>()

let suppress = false

export function createTemplateView(
  template: ParsedTemplate,
  data: JsonObject,
  viewport: ViewPort,
  host: AssetHost,
  dispatch: (names: string[], item: JsonObject | null) => void
): TemplateView {
  const root = document.createElement("div")
  root.className = "otter-root"
  const pageIds = new Map<string, HTMLElement>()
  let current = viewport

  const view: TemplateView = {
    root,
    data,
    template,
    relayout(next) {
      current = next
      placePage()
    },
    rebind() {
      paintNode(pageEl(), template.root, null)
      placePage()
    },
    release() {
      root.querySelectorAll<HTMLElement>("[data-otter-lottie]").forEach((el) => {
        lottieOf.get(el)?.destroy()
      })
      root.replaceChildren()
    },
    element(id) {
      return pageIds.get(id)
    },
    snapshot() {
      writeControls(root, data, true)
    },
    setText(id, value, item) {
      const el = findTarget(id, item)
      if (!el) return
      textOverride.set(el, value)
      const text = el.querySelector(".otter-text") ?? el
      text.textContent = value
    },
    setTextStyle(id, patch, scope) {
      const el = findTarget(id, null)
      if (!el) return
      const text = (el.querySelector(".otter-text") as HTMLElement | null) ?? el
      if (patch.fontSize) {
        const size = displayValue(patch.fontSize, scope)
        text.style.fontSize = `${Number(size) * host.density}px`
      }
      if (patch.color) {
        text.style.color = cssColor(displayValue(patch.color, scope))
      }
      if (patch.text) {
        const value = displayValue(patch.text, scope)
        textOverride.set(el, value)
        text.textContent = value
      }
    },
    setChecked(ids, value, scope) {
      const checked = displayValue(value, scope) === "true"
      for (const id of ids) {
        const el = pageIds.get(id)
        const input = el?.querySelector("input")
        if (!input) continue
        input.checked = checked
        data[id] = checked
      }
    },
    readControl(id) {
      const el = pageIds.get(id)
      const input = el?.querySelector("input, textarea")
      if (input instanceof HTMLInputElement || input instanceof HTMLTextAreaElement) {
        return input.value
      }
      return ""
    },
    listItems(id) {
      return readList(id)
    },
    patchListItem(id, index, patch) {
      const items = readList(id)
      const item = items[index]
      if (!item) return
      Object.assign(item, patch)
      const list = pageIds.get(id)
      const row = list?.querySelectorAll<HTMLElement>(":scope > .otter-item")[index]
      if (row && templateNodeItem(template.root, id)) {
        paintItem(row, templateNodeItem(template.root, id)!, item)
        layoutList(pageIds.get(id)!)
      }
    },
    setProgress(id, fraction) {
      const el = pageIds.get(id)
      const bar = el?.querySelector<HTMLElement>(".otter-progress-bar")
      if (!bar) return
      const clamped = Math.min(1, Math.max(0, fraction))
      const pad = 1
      bar.style.left = `${pad}px`
      bar.style.width = `calc((100% - ${pad * 2}px) * ${clamped})`
    },
    setImage(id, src) {
      const el = pageIds.get(id)
      if (!el) return
      imageOverride.set(el, src)
      const img = el.querySelector("img")
      if (img) applyImage(img, el, src)
    },
    setLottiePlaying(id, playing) {
      const el = pageIds.get(id)
      const anim = el ? lottieOf.get(el) : undefined
      if (!anim) return
      if (playing) anim.play()
      else anim.pause()
    },
  }

  function pageEl(): HTMLElement {
    return root.firstElementChild as HTMLElement
  }

  function findTarget(id: string, item: JsonObject | null): HTMLElement | undefined {
    if (item) {
      for (const row of root.querySelectorAll<HTMLElement>("[data-otter-item]")) {
        if (itemsOf.get(row)?.item !== item) continue
        const inner = row.querySelector<HTMLElement>(`[data-otter-id="${cssEscape(id)}"]`)
        if (inner) return inner
      }
    }
    return pageIds.get(id)
  }

  function readList(id: string): JsonObject[] {
    const key = listDataKey(template.root, id)
    const value = key ? data[key] : undefined
    if (!Array.isArray(value)) return []
    return value.filter(isObject)
  }

  buildPage()
  root.addEventListener("click", (event) => {
    const target = event.target
    if (!(target instanceof Element)) return
    if (target.closest("input, textarea")) return
    const node = target.closest<HTMLElement>("[data-otter-click]")
    if (!node || !root.contains(node)) return
    const names = node.dataset.otterClick?.split(",").filter(Boolean) ?? []
    if (names.length === 0) return
    const row = node.closest<HTMLElement>("[data-otter-item]")
    dispatch(names, row ? itemsOf.get(row)?.item ?? null : null)
  })

  function buildPage() {
    pageIds.clear()
    const layout = layoutTree(toLayout(template.root, data, null, null), current, host.density)
    root.replaceChildren(buildNode(template.root, layout, null))
  }

  function placePage() {
    const layout = layoutTree(toLayout(template.root, data, null, pageEl()), current, host.density)
    placeNode(pageEl(), layout)
    root.querySelectorAll<HTMLElement>("[data-otter-list]").forEach(layoutList)
  }

  function paintNode(el: HTMLElement, node: ParsedNode, item: JsonObject | null) {
    const scope = item ?? data
    applyVisual(el, node, scope)
    if (node.viewName === "OTList") {
      syncList(el, node)
      return
    }
    const kids = childNodes(el)
    node.children.forEach((child, index) => {
      const next = kids[index]
      if (next) paintNode(next, child, item)
    })
  }

  function buildNode(node: ParsedNode, box: LayoutBox, item: JsonObject | null): HTMLElement {
    const el = document.createElement("div")
    el.className = "otter-node"
    el.dataset.otterType = node.viewName
    if (node.id !== "0") {
      el.dataset.otterId = node.id
      if (!item) pageIds.set(node.id, el)
    }
    const scope = item ?? data
    if (node.attrs.onClick) {
      el.dataset.otterClick = node.attrs.onClick
      el.classList.add("otter-click")
    }
    applyFrame(el, box)
    applyVisual(el, node, scope)
    if (node.attrs.glassStyle) mountGlass(el)
    const parent = box.scroll ? scrollPort(el, box) : el
    if (node.viewName === "Text") fillText(el, node, scope)
    else if (node.viewName === "Image") fillImage(el, node, scope)
    else if (node.viewName === "Input") fillInput(el, node, scope, item)
    else if (node.viewName === "CheckBox" || node.viewName === "Radio" || node.viewName === "Switch") {
      fillCheck(el, node, scope, item)
    } else if (node.viewName === "Progress") fillProgress(el, node, scope)
    else if (node.viewName === "Animation") fillLottie(el, node, scope)
    else if (node.viewName === "OTList") {
      el.dataset.otterList = "true"
      el.classList.add("otter-list", node.attrs.listDirection === "horizontal" ? "horizontal" : "vertical")
      syncList(el, node)
    } else {
      node.children.forEach((child, index) => {
        const childBox = box.children[index]
        if (childBox) parent.appendChild(buildNode(child, childBox, item))
      })
    }
    if (node.viewName === "Column" && node.attrs.background?.startsWith("res:") && node.attrs.scroll !== "true") {
      attachPan(el)
    }
    return el
  }

  function scrollPort(el: HTMLElement, box: LayoutBox): HTMLElement {
    el.classList.add("otter-scroll")
    const port = document.createElement("div")
    port.className = "otter-scroll-port"
    port.style.height = `${Math.max(box.height, box.contentHeight)}px`
    el.appendChild(port)
    return port
  }

  function placeNode(el: HTMLElement, box: LayoutBox) {
    applyFrame(el, box)
    const port = el.querySelector<HTMLElement>(":scope > .otter-scroll-port")
    if (port) {
      port.style.height = `${Math.max(box.height, box.contentHeight)}px`
    }
    if (el.dataset.otterList === "true") return
    const kids = childNodes(el)
    box.children.forEach((child, index) => {
      const next = kids[index]
      if (next) placeNode(next, child)
    })
  }

  function childNodes(el: HTMLElement): HTMLElement[] {
    const parent = el.querySelector(":scope > .otter-scroll-port") ?? el
    return [...parent.children].filter((child): child is HTMLElement => {
      return child instanceof HTMLElement && child.classList.contains("otter-node")
    })
  }

  function syncList(el: HTMLElement, node: ParsedNode) {
    const item = node.item
    if (!item) return
    const scrollTop = el.scrollTop
    const scrollLeft = el.scrollLeft
    const values = listValues(node)
    el.replaceChildren()
    const gap = Number(node.attrs.itemPadding ?? "0") * host.density
    values.forEach((value, index) => {
      const row = document.createElement("div")
      row.className = "otter-item"
      row.dataset.otterItem = "true"
      itemsOf.set(row, { item: value })
      if (node.attrs.listDirection === "horizontal") {
        if (index > 0) row.style.marginLeft = `${gap}px`
      } else if (index < values.length - 1) {
        row.style.marginBottom = `${gap}px`
      }
      paintItem(row, item, value)
      el.appendChild(row)
    })
    el.scrollTop = scrollTop
    el.scrollLeft = scrollLeft
    layoutList(el)
  }

  function paintItem(row: HTMLElement, item: ParsedNode, value: JsonObject) {
    const parent = row.parentElement
    const width = parent ? parseFloat(parent.style.width) || parent.clientWidth || current.width : current.width
    const height = parent ? parseFloat(parent.style.height) || parent.clientHeight : 0
    const horizontal = parent?.classList.contains("horizontal") ?? false
    const box = layoutItem(
      toLayout(item, value, null, null, true),
      horizontal ? { height: height || undefined } : { width },
      host.density
    )
    row.style.width = horizontal ? `${box.width}px` : "100%"
    row.style.height = `${box.height}px`
    row.replaceChildren(buildNode(item, box, value))
  }

  function layoutList(el: HTMLElement) {
    const node = findParsed(template.root, el.dataset.otterId)
    const item = node?.item
    if (!item) return
    const horizontal = el.classList.contains("horizontal")
    const width = parseFloat(el.style.width) || el.clientWidth || current.width
    const height = parseFloat(el.style.height) || el.clientHeight
    ;[...el.querySelectorAll<HTMLElement>(":scope > .otter-item")].forEach((row) => {
      const value = itemsOf.get(row)?.item
      if (!value) return
      const box = layoutItem(
        toLayout(item, value, null, row, true),
        horizontal ? { height } : { width },
        host.density
      )
      row.style.width = horizontal ? `${box.width}px` : "100%"
      row.style.height = `${box.height}px`
      const inner = row.firstElementChild
      if (inner instanceof HTMLElement) placeNode(inner, box)
    })
  }

  function listValues(node: ParsedNode): JsonObject[] {
    const raw = getResult(node.attrs.data, data)
    if (!Array.isArray(raw)) return []
    return raw.filter(isObject)
  }

  function fillText(el: HTMLElement, node: ParsedNode, scope: JsonObject) {
    const text = document.createElement("div")
    text.className = "otter-text"
    const value = textOverride.get(el) ?? displayValue(node.attrs.text ?? "", scope)
    text.textContent = value
    styleText(text, node, scope, value, host.density)
    el.appendChild(text)
  }

  function fillImage(el: HTMLElement, node: ParsedNode, scope: JsonObject) {
    const img = document.createElement("img")
    img.alt = ""
    const fit = node.attrs.fit ?? "cover"
    img.style.objectFit = fit === "fill" ? "fill" : fit
    if (node.attrs.placeholder) {
      el.style.background = cssColor(displayValue(node.attrs.placeholder, scope))
    }
    const src = imageOverride.get(el) ?? displayValue(node.attrs.src ?? "", scope)
    applyImage(img, el, src)
    el.appendChild(img)
  }

  function fillInput(el: HTMLElement, node: ParsedNode, scope: JsonObject, item: JsonObject | null) {
    const lines = Number(node.attrs.lines ?? "1")
    const field = lines > 1 ? document.createElement("textarea") : document.createElement("input")
    if (field instanceof HTMLInputElement) {
      const keyboard = node.attrs.inputType ?? "text"
      field.type = keyboard === "password" ? "password" : keyboard === "email" ? "email" : keyboard === "phone" ? "tel" : "text"
      if (keyboard === "number") field.inputMode = "decimal"
    }
    if (node.attrs.maxLength) field.maxLength = Number(node.attrs.maxLength)
    field.placeholder = displayValue(node.attrs.hint ?? "", scope)
    field.style.color = cssColor(displayValue(node.attrs.textColor ?? "#1F1A17", scope))
    field.style.setProperty("--otter-hint", cssColor(displayValue(node.attrs.hintColor ?? "#8A8178", scope)))
    field.style.fontSize = `${Number(node.attrs.textSize ?? "14") * host.density}px`
    field.style.textAlign = cssAlign(node.attrs.textAlign)
    const raw = node.attrs.text ?? ""
    const shown = raw ? displayValue(raw, scope) : ""
    field.value = raw.startsWith("$") && shown === raw ? "" : shown
    if (node.id !== "0") el.dataset.otterField = node.id
    applyPadding(field, node, host.density)
    field.addEventListener("click", (event) => event.stopPropagation())
    field.addEventListener("input", () => {
      if (suppress) return
      if (node.id !== "0") data[node.id] = field.value
      const names = node.attrs.onChange?.split(",").filter(Boolean) ?? []
      if (names.length) dispatch(names, item)
    })
    el.appendChild(field)
  }

  function fillCheck(el: HTMLElement, node: ParsedNode, scope: JsonObject, item: JsonObject | null) {
    const label = document.createElement("label")
    label.className = `otter-check${node.viewName === "Switch" ? " otter-switch" : ""}`
    const input = document.createElement("input")
    input.type = node.viewName === "Radio" ? "radio" : "checkbox"
    input.checked = displayValue(node.attrs.checked ?? "false", scope) === "true"
    if (node.attrs.group) input.name = displayValue(node.attrs.group, scope)
    const tint = cssColor(displayValue(node.attrs.tint ?? "#1F6F6A", scope))
    input.style.accentColor = tint
    input.style.setProperty("--otter-tint", tint)
    const caption = document.createElement("span")
    caption.textContent = displayValue(node.attrs.text ?? "", scope)
    caption.style.color = cssColor(displayValue(node.attrs.textColor ?? "#1F1A17", scope))
    caption.style.fontSize = `${Number(node.attrs.textSize ?? "14") * host.density}px`
    if (node.id !== "0") el.dataset.otterField = node.id
    input.addEventListener("click", (event) => event.stopPropagation())
    input.addEventListener("change", () => {
      if (suppress) return
      if (input.type === "radio" && input.name) {
        root.querySelectorAll<HTMLInputElement>(`input[type="radio"][name="${CSS.escape(input.name)}"]`).forEach((other) => {
          const holder = other.closest<HTMLElement>("[data-otter-field]")
          if (holder?.dataset.otterField) data[holder.dataset.otterField] = other.checked
        })
      } else if (node.id !== "0") {
        data[node.id] = input.checked
      }
      const names = node.attrs.onChange?.split(",").filter(Boolean) ?? []
      if (names.length) dispatch(names, item)
    })
    if (node.viewName === "Switch") {
      const face = document.createElement("span")
      face.className = "otter-switch-face"
      const knob = document.createElement("span")
      knob.className = "otter-knob"
      face.append(input, knob)
      label.append(face, caption)
    } else {
      label.append(input, caption)
    }
    el.appendChild(label)
  }

  function fillProgress(el: HTMLElement, node: ParsedNode, scope: JsonObject) {
    const track = document.createElement("div")
    track.className = "otter-progress-track"
    const bar = document.createElement("div")
    bar.className = "otter-progress-bar"
    const wrap = document.createElement("div")
    wrap.className = "otter-progress"
    const from = Number(displayValue(node.attrs.valueMin ?? "0", scope)) || 0
    const to = Number(displayValue(node.attrs.valueMax ?? "1", scope))
    const end = Number.isFinite(to) ? to : 1
    const height = parseFloat(el.style.height) || 0
    const pad = 1
    const full = Math.max(0, height - pad * 2)
    const slim = 6 * host.density
    const thick = full > slim * 2.2 ? slim : full || slim
    const top = Math.max(0, (height - thick) / 2)
    track.style.background = cssBackground(displayValue(node.attrs.strokeColor ?? "#888888", scope))
    bar.style.background = cssBackground(displayValue(node.attrs.trailColor ?? "#ff0000", scope))
    for (const piece of [track, bar]) {
      piece.style.top = `${top}px`
      piece.style.height = `${thick}px`
      piece.style.borderRadius = `${thick / 2}px`
    }
    track.style.left = `${pad}px`
    track.style.right = `${pad}px`
    const start = Math.min(1, Math.max(0, from))
    const span = Math.min(1, Math.max(0, end - from))
    bar.style.left = `calc(${pad}px + (100% - ${pad * 2}px) * ${start})`
    bar.style.width = `calc((100% - ${pad * 2}px) * ${span})`
    if (node.attrs.animateEnable === "true") bar.style.transition = "width 300ms ease-in-out, left 300ms ease-in-out"
    const radius = node.attrs.radius
    if (radius) {
      wrap.style.borderRadius = `${Number(radius) * host.density}px`
    }
    wrap.append(track, bar)
    el.appendChild(wrap)
  }

  function fillLottie(el: HTMLElement, node: ParsedNode, scope: JsonObject) {
    el.dataset.otterLottie = "true"
    const src = displayValue(node.attrs.animationSrc ?? "", scope)
    const url = host.resolveLottie(src)
    const repeat = node.attrs.repeatCount ?? "infinite"
    const autoplay = node.attrs.autoPlay !== "false"
    void import("lottie-web").then((mod) => {
      const anim = mod.default.loadAnimation({
        container: el,
        renderer: "svg",
        loop: repeat === "infinite" ? true : Math.max(0, Number(repeat)),
        autoplay,
        path: url,
      })
      if (node.attrs.repeatMode === "reverse") {
        let direction: 1 | -1 = 1
        anim.addEventListener("loopComplete", () => {
          direction = direction === 1 ? -1 : 1
          anim.setDirection(direction)
        })
      }
      lottieOf.set(el, anim)
    })
  }

  function applyImage(img: HTMLImageElement, el: HTMLElement, src: string) {
    const resolved = host.resolveImage(src)
    if (!resolved || resolved.startsWith("$")) {
      img.removeAttribute("src")
      return
    }
    img.src = resolved
  }

  function applyVisual(el: HTMLElement, node: ParsedNode, scope: JsonObject) {
    const hidden = node.attrs.visible != null && displayValue(node.attrs.visible, scope) === "false"
    el.style.display = hidden ? "none" : ""
    const background = node.attrs.background ? displayValue(node.attrs.background, scope) : ""
    if (background.startsWith("res:")) {
      const url = host.resolveImage(background)
      el.style.backgroundImage = `url("${url}")`
      el.style.backgroundSize = node.viewName === "Column" ? "100% auto" : "cover"
      el.style.backgroundPosition = "center top"
      el.style.backgroundRepeat = "no-repeat"
      el.style.backgroundColor = ""
    } else if (background) {
      el.style.backgroundImage = ""
      el.style.background = cssBackground(background)
    }
    applyRadius(el, node, host.density)
    const shadows: string[] = []
    if (node.attrs.borderWidth && node.attrs.borderColor) {
      const width = Number(node.attrs.borderWidth) * host.density
      const color = cssColor(displayValue(node.attrs.borderColor, scope))
      shadows.push(`inset 0 0 0 ${width}px ${color}`)
    }
    if (node.attrs.glassStyle) {
      const clear = node.attrs.glassStyle === "clear"
      el.dataset.glassStyle = clear ? "clear" : "regular"
      el.dataset.glassTint = node.attrs.glassTint ? displayValue(node.attrs.glassTint, scope) : ""
      el.dataset.glassInteractive = node.attrs.glassInteractive === "true" ? "true" : "false"
      el.dataset.glassRadius = String(glassRadius(node) * host.density)
      el.dataset.glassDensity = String(host.density)
      el.classList.toggle("otter-glass-clear", clear)
      el.classList.toggle("otter-glass-regular", !clear)
      const shadow = (clear ? 2 : 6) * host.density
      shadows.push(`0 ${shadow}px ${shadow * 2}px rgba(0, 0, 0, 0.16)`)
    }
    if (shadows.length > 0) el.style.boxShadow = shadows.join(", ")
    if (node.viewName === "Text") {
      const text = el.querySelector<HTMLElement>(".otter-text")
      if (text) {
        const value = textOverride.get(el) ?? displayValue(node.attrs.text ?? "", scope)
        text.textContent = value
        styleText(text, node, scope, value, host.density)
      }
    }
    if (node.viewName === "Image") {
      const img = el.querySelector("img")
      if (img) {
        const src = imageOverride.get(el) ?? displayValue(node.attrs.src ?? "", scope)
        applyImage(img, el, src)
      }
    }
  }

  function toLayout(node: ParsedNode, scope: JsonObject, item: JsonObject | null, existing: HTMLElement | null, mirrorEnd = false): LayoutNode {
    const hidden = node.attrs.visible != null && displayValue(node.attrs.visible, scope) === "false"
    const justify = node.attrs.justifyContent
    let mirror = false
    let resolvedJustify = justify
    if (justify && isExpression(justify)) {
      resolvedJustify = displayValue(justify, scope)
      if (mirrorEnd && resolvedJustify === "end") {
        mirror = true
        resolvedJustify = "start"
      }
    }
    const textNode = node.viewName === "Text"
    const shown = existing ? textOverride.get(existing) : undefined
    return {
      width: node.attrs.width,
      height: node.attrs.height,
      minWidth: node.attrs.minWidth,
      minHeight: node.attrs.minHeight,
      maxWidth: node.attrs.maxWidth,
      maxHeight: node.attrs.maxHeight,
      padding: edges(node.attrs, "padding"),
      margin: edges(node.attrs, "margin"),
      grow: Number(node.attrs.flexGrow ?? "0") || 0,
      aspectRatio: node.attrs.aspectRatio ? Number(node.attrs.aspectRatio) : undefined,
      alignSelf: node.attrs.alignSelf,
      justify: resolvedJustify,
      align: node.attrs.alignItems,
      wrap: node.attrs.flexWrap === "wrap",
      hidden,
      scroll: node.attrs.scroll === "true",
      mirror,
      direction: node.viewName === "Row" ? "row" : node.viewName === "Column" ? "column" : "leaf",
      text: textNode
        ? {
            text: shown ?? displayValue(node.attrs.text ?? "", scope),
            fontSize: Number(node.attrs.textSize ?? "12") * host.density,
            fontWeight: fontWeightValue(node.attrs.fontWeight),
            maxLines: node.attrs.maxLines ? Number(node.attrs.maxLines) : undefined,
          }
        : undefined,
      children:
        node.viewName === "OTList"
          ? []
          : node.children.map((child, index) => {
              const childEl = existing ? childNodes(existing)[index] ?? null : null
              return toLayout(child, item ?? scope, item, childEl)
            }),
    }
  }

  return view
}

function applyFrame(el: HTMLElement, box: LayoutBox) {
  el.style.left = `${box.x}px`
  el.style.top = `${box.y}px`
  el.style.width = `${Math.max(0, box.width)}px`
  el.style.height = `${Math.max(0, box.height)}px`
}

function styleText(text: HTMLElement, node: ParsedNode, scope: JsonObject, value: string, density = 1) {
  const size = Number(node.attrs.textSize ?? "12") * density
  const line = lineBox(size, fontWeightValue(node.attrs.fontWeight))
  text.style.fontSize = `${size}px`
  text.style.lineHeight = `${line}px`
  text.style.fontWeight = String(fontWeightValue(node.attrs.fontWeight))
  text.style.color = cssColor(displayValue(node.attrs.textColor ?? "#000000", scope))
  text.style.textAlign = cssAlign(node.attrs.textAlign)
  const lines = node.attrs.maxLines ? Number(node.attrs.maxLines) : 0
  if (node.attrs.ellipsis === "true" && lines > 1) {
    text.style.display = "-webkit-box"
    text.style.webkitLineClamp = String(lines)
    text.style.webkitBoxOrient = "vertical"
  } else if (node.attrs.ellipsis === "true") {
    text.style.whiteSpace = "nowrap"
    text.style.textOverflow = "ellipsis"
  } else if (lines > 0) {
    text.style.maxHeight = `${lines * line}px`
  }
  if (!value) text.textContent = ""
  applyPadding(text, node, density)
}

function applyPadding(el: HTMLElement, node: ParsedNode, density: number) {
  const pad = edges(node.attrs, "padding")
  if (pad.start || pad.end || pad.top || pad.bottom) {
    el.style.padding = `${pad.top * density}px ${pad.end * density}px ${pad.bottom * density}px ${pad.start * density}px`
  }
}

function glassRadius(node: ParsedNode): number {
  if (node.attrs.radius) return Number(node.attrs.radius)
  return Math.max(
    Number(node.attrs.leftTopRadius ?? 0),
    Number(node.attrs.rightTopRadius ?? 0),
    Number(node.attrs.rightBottomRadius ?? 0),
    Number(node.attrs.leftBottomRadius ?? 0)
  )
}

function applyRadius(el: HTMLElement, node: ParsedNode, density: number) {
  const px = (raw: string | undefined) => `${(Number(raw) || 0) * density}px`
  if (node.attrs.radius) {
    el.style.borderRadius = px(node.attrs.radius)
    return
  }
  const tl = node.attrs.leftTopRadius
  const tr = node.attrs.rightTopRadius
  const br = node.attrs.rightBottomRadius
  const bl = node.attrs.leftBottomRadius
  if (tl || tr || br || bl) {
    el.style.borderRadius = `${px(tl)} ${px(tr)} ${px(br)} ${px(bl)}`
  }
}

function edges(attrs: Record<string, string>, prefix: string): Edges {
  if (attrs[prefix]) {
    const value = Number(attrs[prefix]) || 0
    return { start: value, end: value, top: value, bottom: value }
  }
  return {
    start: Number(attrs[`${prefix}Start`] ?? "0") || 0,
    end: Number(attrs[`${prefix}End`] ?? "0") || 0,
    top: Number(attrs[`${prefix}Top`] ?? "0") || 0,
    bottom: Number(attrs[`${prefix}Bottom`] ?? "0") || 0,
  }
}

function cssAlign(value: string | undefined): string {
  if (value === "center") return "center"
  if (value === "end") return "right"
  if (value === "start") return "left"
  return "left"
}

function attachPan(el: HTMLElement) {
  const image = new Image()
  const raw = el.style.backgroundImage.slice(5, -2)
  image.src = raw.replace(/^"|"$/g, "")
  image.onload = () => {
    if (image.naturalWidth <= 0) return
    const shown = image.naturalHeight * (el.clientWidth / image.naturalWidth)
    const extra = shown - el.clientHeight
    if (extra <= 1) return
    let offset = 0
    let last = 0
    let dragging = false
    el.style.touchAction = "none"
    el.addEventListener("pointerdown", (event) => {
      dragging = true
      last = event.clientY
      el.setPointerCapture(event.pointerId)
    })
    el.addEventListener("pointermove", (event) => {
      if (!dragging) return
      offset = Math.min(extra, Math.max(0, offset - (event.clientY - last)))
      last = event.clientY
      el.style.backgroundPosition = `center ${-offset}px`
    })
    const end = () => {
      dragging = false
    }
    el.addEventListener("pointerup", end)
    el.addEventListener("pointercancel", end)
  }
}

function writeControls(root: HTMLElement, data: JsonObject, skipItems: boolean) {
  root.querySelectorAll<HTMLElement>("[data-otter-field]").forEach((el) => {
    if (skipItems && el.closest("[data-otter-item]")) return
    const id = el.dataset.otterField
    if (!id) return
    const input = el.querySelector("input, textarea")
    if (input instanceof HTMLInputElement && (input.type === "checkbox" || input.type === "radio")) {
      data[id] = input.checked
    } else if (input instanceof HTMLInputElement || input instanceof HTMLTextAreaElement) {
      data[id] = input.value
    }
  })
}

function listDataKey(node: ParsedNode, id: string): string | null {
  if (node.viewName === "OTList" && node.id === id) {
    const expr = node.attrs.data ?? ""
    return expr.startsWith("$") ? expr.slice(1).split(".")[0] : null
  }
  for (const child of node.children) {
    const found = listDataKey(child, id)
    if (found) return found
  }
  return node.item ? listDataKey(node.item, id) : null
}

function templateNodeItem(node: ParsedNode, id: string): ParsedNode | null {
  if (node.viewName === "OTList" && node.id === id) return node.item
  for (const child of node.children) {
    const found = templateNodeItem(child, id)
    if (found) return found
  }
  return null
}

function findParsed(node: ParsedNode, id: string | undefined): ParsedNode | null {
  if (!id) return null
  if (node.id === id) return node
  for (const child of node.children) {
    const found = findParsed(child, id)
    if (found) return found
  }
  return null
}

function cssEscape(value: string): string {
  return typeof CSS !== "undefined" && CSS.escape ? CSS.escape(value) : value
}

function isObject(value: Json | unknown): value is JsonObject {
  return value != null && typeof value === "object" && !Array.isArray(value)
}
