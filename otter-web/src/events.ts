import { displayValue, getResult, isExpression } from "./expression"
import { ExpansionCenter } from "./expansion"
import { showToast } from "./toast"
import type { Json, JsonObject, EventSpec } from "./types"
import type { TemplateView } from "./view"

export type PageNavigator = {
  open: (page: string, params: JsonObject | undefined, item: JsonObject | null, data: JsonObject) => void
  replace: (page: string, params: JsonObject | undefined, item: JsonObject | null, data: JsonObject) => void
  popTo: (page: string, params: JsonObject | undefined, item: JsonObject | null, data: JsonObject) => boolean
  back: (params: JsonObject | undefined) => boolean
  finish: () => void
}

const CANNOT_OPEN = "这个页面还打不开"
const CANNOT_USE = "这个操作还不能用"

export function runEvents(view: TemplateView, names: string[], item: JsonObject | null, nav: PageNavigator | null) {
  for (const name of names) {
    const event = view.template.events[name]
    if (event) runEvent(view, event, item, nav)
  }
}

function runEvent(view: TemplateView, event: EventSpec, item: JsonObject | null, nav: PageNavigator | null) {
  const scope = merge(view.data, item)
  if (event.kind === "toast") {
    showToast(displayValue(event.message, scope))
    return
  }
  if (event.kind === "setText") {
    view.setText(event.target, displayValue(event.value, scope), item)
    return
  }
  if (event.kind === "setTextStyle") {
    view.setTextStyle(event.target, event, scope)
    return
  }
  if (event.kind === "setChecked") {
    view.setChecked(event.targets, event.value, scope)
    return
  }
  if (event.kind === "append") {
    append(view, event, scope)
    return
  }
  if (event.kind === "update") {
    update(view, event, scope)
    return
  }
  if (event.kind === "remove") {
    remove(view, event, scope)
    return
  }
  if (event.kind === "host") {
    const name = displayValue(event.name, scope)
    if (!name || name === "null") {
      showToast(CANNOT_USE)
      return
    }
    const params = event.params ? evaluateParams(event.params, scope) : undefined
    if (!ExpansionCenter.dispatchHost(name, params)) showToast(CANNOT_USE)
    return
  }
  if (!nav) {
    if (event.kind === "open") {
      const page = displayValue(event.page, scope)
      if (!page || page === "null" || !ExpansionCenter.pageOpener) {
        showToast(CANNOT_OPEN)
        return
      }
      ExpansionCenter.pageOpener(page)
      return
    }
    if (event.kind === "back") {
      navFinish(null)
    }
    return
  }
  if (event.kind === "open") {
    const page = displayValue(event.page, scope)
    if (!page || page === "null") {
      showToast(CANNOT_OPEN)
      return
    }
    nav.open(page, event.params, item, view.data)
    return
  }
  if (event.kind === "replace") {
    const page = displayValue(event.page, scope)
    if (!page || page === "null") {
      showToast(CANNOT_OPEN)
      return
    }
    nav.replace(page, event.params, item, view.data)
    return
  }
  if (event.kind === "popTo") {
    const page = displayValue(event.page, scope)
    if (!page || page === "null" || !nav.popTo(page, event.params, item, view.data)) {
      showToast(CANNOT_OPEN)
    }
    return
  }
  if (event.kind === "back") {
    if (!nav.back(event.params)) nav.finish()
  }
}

function navFinish(nav: PageNavigator | null) {
  if (nav) nav.finish()
}

function append(view: TemplateView, event: Extract<EventSpec, { kind: "append" }>, scope: JsonObject) {
  const text = view.readControl(event.from).trim()
  if (!text) {
    if (event.empty) showToast(displayValue(event.empty, scope))
    return
  }
  const items = ensureArray(view.data, event.data)
  const item: JsonObject = {}
  for (const [key, value] of Object.entries(event.item)) {
    item[key] = displayValue(value, scope)
  }
  item[event.field] = text
  items.push(item)
  view.data[event.data] = items
  const input = view.element(event.from)?.querySelector("input, textarea")
  if (input instanceof HTMLInputElement || input instanceof HTMLTextAreaElement) {
    input.value = ""
    view.data[event.from] = ""
  }
  view.rebind()
}

function update(view: TemplateView, event: Extract<EventSpec, { kind: "update" }>, scope: JsonObject) {
  const index = resolveIndex(event.index, scope)
  if (index == null) return
  const patch: Record<string, string> = {}
  for (const [key, value] of Object.entries(event.item)) {
    patch[key] = displayValue(value, scope)
  }
  view.patchListItem(event.list, index, patch)
}

function remove(view: TemplateView, event: Extract<EventSpec, { kind: "remove" }>, scope: JsonObject) {
  const index = resolveIndex(event.index, scope)
  const key = listKey(view, event.list)
  const items = ensureArray(view.data, key)
  if (index == null || index >= items.length) return
  items.splice(index, 1)
  view.data[key] = items
  view.rebind()
}

function listKey(view: TemplateView, id: string): string {
  const node = findList(view.template.root, id)
  const expr = node?.attrs.data ?? ""
  return expr.startsWith("$") ? expr.slice(1).split(/[.[]/)[0] : id
}

function findList(node: TemplateView["template"]["root"], id: string): TemplateView["template"]["root"] | null {
  if (node.viewName === "OTList" && node.id === id) return node
  for (const child of node.children) {
    const found = findList(child, id)
    if (found) return found
  }
  return null
}

function ensureArray(data: JsonObject, key: string): JsonObject[] {
  const current = data[key]
  if (Array.isArray(current)) return current.filter(isObject)
  const created: JsonObject[] = []
  data[key] = created
  return created
}

function resolveIndex(raw: string, scope: JsonObject): number | null {
  const shown = isExpression(raw) ? getResult(raw, scope) : Number(raw)
  const value = typeof shown === "number" ? shown : Number(shown)
  if (!Number.isInteger(value) || value < 0) return null
  return value
}

export function evaluateParams(raw: JsonObject, scope: JsonObject): JsonObject {
  const copy: JsonObject = {}
  for (const [key, value] of Object.entries(raw)) {
    copy[key] = evaluateValue(value, scope)
  }
  return copy
}

function evaluateValue(value: Json, scope: JsonObject): Json {
  if (typeof value === "string") {
    if (!isExpression(value)) return value
    const result = getResult(value, scope)
    if (result == null) return value
    if (typeof result === "string" || typeof result === "number" || typeof result === "boolean") return result
    return value
  }
  if (Array.isArray(value)) return value.map((item) => evaluateValue(item, scope))
  if (isObject(value)) return evaluateParams(value, scope)
  return value
}

export function merge(base: JsonObject | null | undefined, overlay: JsonObject | null | undefined): JsonObject {
  return { ...(base ?? {}), ...(overlay ?? {}) }
}

export function sameOverlay(data: JsonObject | null, overlay: JsonObject | undefined): boolean {
  if (!overlay || Object.keys(overlay).length === 0) return true
  if (!data) return false
  return Object.entries(overlay).every(([key, value]) => JSON.stringify(data[key]) === JSON.stringify(value))
}

function isObject(value: unknown): value is JsonObject {
  return value != null && typeof value === "object" && !Array.isArray(value)
}
