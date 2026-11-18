import fs from "node:fs"
import path from "node:path"
import { describe, expect, it } from "vitest"
import { displayValue, getResult } from "../src/expression"
import { designScale } from "../src/view"
import { glassAppearance, parseGlassColor } from "../src/glass"
import { parseTemplate } from "../src/parser"
import { parseRoutes } from "../src/routes"
import { TemplateParseException } from "../src/types"

const templates = path.resolve(import.meta.dirname, "../templates")

function walk(dir: string): string[] {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) return walk(full)
    return entry.name.endsWith(".json") ? [full] : []
  })
}

describe("模版协议", () => {
  const files = walk(templates)

  it("能解析 Demo 里的全部模版和路由", () => {
    const templatesOnly = files.filter((file) => !file.includes(`${path.sep}mock-data${path.sep}`) && !path.basename(file).startsWith("routes"))
    const routes = files.filter((file) => path.basename(file).startsWith("routes"))
    expect(templatesOnly.length).toBeGreaterThan(20)
    for (const file of templatesOnly) {
      expect(() => parseTemplate(fs.readFileSync(file, "utf8")), file).not.toThrow()
    }
    for (const file of routes) {
      expect(() => parseRoutes(fs.readFileSync(file, "utf8")), file).not.toThrow()
    }
  })

  it("拒绝未知节点和悬空事件", () => {
    expect(() => parseTemplate(JSON.stringify({ layout: { type: "web", layout: { width: "fill", height: "wrap" } } }))).toThrow(
      TemplateParseException
    )
    expect(() =>
      parseTemplate(
        JSON.stringify({
          layout: {
            type: "text",
            text: "你好",
            layout: { width: "fill", height: "wrap" },
            onClick: ["missing"],
          },
        })
      )
    ).toThrow(/不存在的事件/)
  })
})

describe("表达式", () => {
  it("读取字段、缺省和三元", () => {
    expect(getResult("$title", { title: "今天" })).toBe("今天")
    expect(displayValue("$title", { title: "今天" })).toBe("今天")
    expect(displayValue("$missing", {})).toBe("$missing")
    expect(displayValue(" $temTip != null ? $temTip : '热死了'", { temTip: null })).toBe("热死了")
    expect(displayValue("$week != null ? $week : '热到没度数'", { week: "周一" })).toBe("周一")
    expect(getResult("size($items)", { items: [{}, {}] })).toBe(2)
    expect(getResult("env('isAndroid')", {})).toBe(false)
    expect(getResult("env('isWeb')", {})).toBe(true)
    expect(displayValue("普通文案", { title: "今天" })).toBe("普通文案")
  })
})

describe("设计宽", () => {
  it("和 375 基准的窗口缩放一致", () => {
    expect(designScale(375)).toBe(1)
    expect(designScale(420)).toBeCloseTo(420 / 375)
    expect(designScale(200)).toBe(0.88)
    expect(designScale(800)).toBeCloseTo(480 / 375)
    expect(designScale(0)).toBe(1)
  })
})

describe("液态玻璃", () => {
  it("regular 中间结霜，clear 边缘折得更开", () => {
    const regular = glassAppearance("regular", undefined, 1)
    const clear = glassAppearance("clear", undefined, 1)
    expect(regular.frost).toBe(6)
    expect(regular.refraction).toBe(12)
    expect(clear.frost).toBe(0)
    expect(clear.refraction).toBe(18)
    expect(clear.dispersion).toBeGreaterThan(regular.dispersion)
    expect(parseGlassColor("#B3FFFFFF", false)[3]).toBeCloseTo(0xb3 / 255)
    expect(parseGlassColor("#8034C759", false).slice(0, 3)).toEqual([0x34 / 255, 0xc7 / 255, 0x59 / 255])
  })
})
