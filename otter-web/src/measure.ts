const FONT =
  '-apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", "Microsoft YaHei", sans-serif'

export type TextMeasure = {
  text: string
  fontSize: number
  fontWeight: number
  maxLines?: number
}

let probe: HTMLDivElement | null = null

export function fontFamily(): string {
  return FONT
}

export function fontWeightValue(name: string | undefined): number {
  if (name === "medium") return 500
  if (name === "bold") return 700
  return 400
}

export function lineBox(fontSize: number, fontWeight: number): number {
  if (typeof document === "undefined") return Math.ceil(fontSize * 1.2)
  const el = probe ?? (probe = document.createElement("div"))
  if (!el.isConnected) {
    el.style.position = "absolute"
    el.style.left = "-10000px"
    el.style.top = "0"
    el.style.visibility = "hidden"
    el.style.padding = "0"
    el.style.margin = "0"
    document.body.appendChild(el)
  }
  el.style.fontFamily = FONT
  el.style.fontSize = `${fontSize}px`
  el.style.fontWeight = String(fontWeight)
  el.style.lineHeight = "normal"
  el.style.whiteSpace = "pre"
  el.style.width = "auto"
  el.textContent = "字"
  return Math.max(1, Math.ceil(el.getBoundingClientRect().height))
}

export function measureText(spec: TextMeasure, maxWidth: number): { width: number; height: number } {
  const text = spec.text.length > 0 ? spec.text : " "
  const line = lineBox(spec.fontSize, spec.fontWeight)
  if (typeof document === "undefined") {
    return estimate(text, spec, maxWidth, line)
  }
  const el = probe ?? (probe = document.createElement("div"))
  if (!el.isConnected) {
    el.style.position = "absolute"
    el.style.left = "-10000px"
    el.style.top = "0"
    el.style.visibility = "hidden"
    el.style.padding = "0"
    el.style.margin = "0"
    el.style.boxSizing = "border-box"
    document.body.appendChild(el)
  }
  el.style.fontFamily = FONT
  el.style.fontSize = `${spec.fontSize}px`
  el.style.fontWeight = String(spec.fontWeight)
  el.style.lineHeight = `${line}px`
  el.style.whiteSpace = "pre"
  el.style.wordBreak = "normal"
  el.style.width = "auto"
  el.style.maxHeight = "none"
  el.style.overflow = "visible"
  el.textContent = text
  const intrinsic = Math.ceil(el.getBoundingClientRect().width)
  const limit = Number.isFinite(maxWidth) ? Math.max(0, maxWidth) : intrinsic
  const width = Math.min(intrinsic, limit)
  if (width >= intrinsic) {
    const lines = spec.maxLines ? Math.min(1, spec.maxLines) : 1
    return { width, height: lines * line }
  }
  el.style.whiteSpace = "pre-wrap"
  el.style.wordBreak = "break-word"
  el.style.width = `${width}px`
  el.style.maxHeight = spec.maxLines ? `${spec.maxLines * line}px` : "none"
  el.style.overflow = "hidden"
  const height = Math.max(line, Math.ceil(el.getBoundingClientRect().height))
  return { width, height }
}

function estimate(
  text: string,
  spec: TextMeasure,
  maxWidth: number,
  line: number
): { width: number; height: number } {
  const unit = spec.fontSize
  let width = 0
  for (const ch of text) {
    width += ch.charCodeAt(0) > 255 ? unit : unit * 0.56
  }
  width = Math.ceil(width)
  if (!Number.isFinite(maxWidth) || maxWidth <= 0) {
    return { width, height: line }
  }
  const lines = Math.max(1, Math.ceil(width / maxWidth))
  const used = spec.maxLines ? Math.min(lines, spec.maxLines) : lines
  return { width: Math.min(width, Math.ceil(maxWidth)), height: used * line }
}
