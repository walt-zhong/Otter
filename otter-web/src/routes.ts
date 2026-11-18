import { TemplateParseException, type JsonObject } from "./types"

const namePattern = /^[A-Za-z_][A-Za-z0-9_]*$/

export type PageRoute = {
  template: string
  data: string | null
}

export type PageRouteTable = {
  start: string
  pages: Record<string, PageRoute>
}

export function parseRoutes(json: string): PageRouteTable {
  let root: unknown
  try {
    root = JSON.parse(json)
  } catch (error) {
    const message = error instanceof Error ? error.message : ""
    throw new TemplateParseException(`路由不是合法 JSON：${message}`)
  }
  if (!isObject(root)) {
    throw new TemplateParseException("路由必须是 JSON 对象")
  }
  requireKeys(root, "$", new Set(["start", "pages"]), new Set(["start", "pages"]))
  const start = requireString(root.start, "$.start")
  if (!namePattern.test(start)) {
    throw new TemplateParseException(`$.start「${start}」必须是字母或下划线开头的标识符`)
  }
  const pagesObject = requireObject(root.pages, "$.pages")
  if (Object.keys(pagesObject).length === 0) {
    throw new TemplateParseException("$.pages 不能是空对象")
  }
  const pages: Record<string, PageRoute> = {}
  for (const [name, raw] of Object.entries(pagesObject)) {
    if (!namePattern.test(name)) {
      throw new TemplateParseException(`$.pages 的页面名「${name}」必须是字母或下划线开头的标识符`)
    }
    const page = requireObject(raw, `$.pages.${name}`)
    requireKeys(page, `$.pages.${name}`, new Set(["template", "data"]), new Set(["template"]))
    const template = requireString(page.template, `$.pages.${name}.template`)
    if (!template) {
      throw new TemplateParseException(`$.pages.${name}.template 不能是空字符串`)
    }
    let data: string | null = null
    if ("data" in page) {
      data = requireString(page.data, `$.pages.${name}.data`)
      if (!data) {
        throw new TemplateParseException(`$.pages.${name}.data 不能是空字符串`)
      }
    }
    pages[name] = { template, data }
  }
  if (!pages[start]) {
    throw new TemplateParseException(`$.start 引用了不存在的页面 ${start}`)
  }
  return { start, pages }
}

function requireObject(value: unknown, path: string): JsonObject {
  if (!isObject(value)) throw new TemplateParseException(`${path} 必须是对象`)
  return value
}

function requireString(value: unknown, path: string): string {
  if (typeof value !== "string") throw new TemplateParseException(`${path} 必须是字符串`)
  return value
}

function requireKeys(node: JsonObject, path: string, allowed: Set<string>, required: Set<string>) {
  for (const key of Object.keys(node)) {
    if (!allowed.has(key)) throw new TemplateParseException(`${path}.${key} 不是这里能写的字段`)
  }
  for (const key of required) {
    if (!(key in node)) throw new TemplateParseException(`${path} 缺少 ${key}`)
  }
}

function isObject(value: unknown): value is JsonObject {
  return value != null && typeof value === "object" && !Array.isArray(value)
}
