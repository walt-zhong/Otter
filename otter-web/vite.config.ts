import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { defineConfig, type Plugin } from "vite"

const root = path.dirname(fileURLToPath(import.meta.url))
const templates = path.join(root, "templates")
const android = path.resolve(root, "../otter-android/Demo/src/main")
const assets = path.join(android, "assets")
const drawable = path.join(android, "res/drawable")
const drawableNodpi = path.join(android, "res/drawable-nodpi")
const rawKey = path.resolve(root, "../otter-android/Demo/src/debug/res/raw/otter_dev_public.bin")

function clientAssets(): Plugin {
  const serve = (request: string, response: import("node:http").ServerResponse, next: () => void) => {
    const url = decodeURIComponent(request.split("?")[0] ?? "")
    if (!url.startsWith("/client/")) {
      next()
      return
    }
    const rel = url.slice("/client/".length)
    if (rel === "raw/otter_dev_public.bin") {
      response.setHeader("Content-Type", "application/octet-stream")
      fs.createReadStream(rawKey).pipe(response)
      return
    }
    if (rel.startsWith("templates/")) {
      const file = safeJoin(templates, rel.slice("templates/".length))
      if (!file || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
        response.statusCode = 404
        response.end()
        return
      }
      response.setHeader("Content-Type", "application/json")
      fs.createReadStream(file).pipe(response)
      return
    }
    if (rel.startsWith("res/")) {
      const name = path.basename(rel).replace(/\.(svg|jpe?g|png)$/i, "")
      const jpg = path.join(drawableNodpi, `${name}.jpg`)
      if (fs.existsSync(jpg)) {
        response.setHeader("Content-Type", "image/jpeg")
        fs.createReadStream(jpg).pipe(response)
        return
      }
      const xml = path.join(drawable, `${name}.xml`)
      if (!fs.existsSync(xml)) {
        response.statusCode = 404
        response.end()
        return
      }
      response.setHeader("Content-Type", "image/svg+xml")
      response.end(vectorToSvg(fs.readFileSync(xml, "utf8")))
      return
    }
    const file = safeJoin(assets, rel)
    if (!file || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
      response.statusCode = 404
      response.end()
      return
    }
    response.setHeader("Content-Type", contentType(file))
    fs.createReadStream(file).pipe(response)
  }
  return {
    name: "otter-client-assets",
    configureServer(server) {
      server.middlewares.use((req, res, next) => serve(req.url ?? "", res, next))
    },
    configurePreviewServer(server) {
      server.middlewares.use((req, res, next) => serve(req.url ?? "", res, next))
    },
  }
}

function safeJoin(base: string, rel: string): string | null {
  const full = path.resolve(base, rel)
  if (full !== base && !full.startsWith(base + path.sep)) return null
  return full
}

function contentType(file: string): string {
  if (file.endsWith(".json")) return "application/json"
  if (file.endsWith(".jpg") || file.endsWith(".jpeg")) return "image/jpeg"
  if (file.endsWith(".png")) return "image/png"
  if (file.endsWith(".svg")) return "image/svg+xml"
  return "application/octet-stream"
}

function vectorToSvg(xml: string): string {
  const width = /android:width="([0-9.]+)dp"/.exec(xml)?.[1] ?? "48"
  const height = /android:height="([0-9.]+)dp"/.exec(xml)?.[1] ?? "48"
  const vw = /android:viewportWidth="([0-9.]+)"/.exec(xml)?.[1] ?? width
  const vh = /android:viewportHeight="([0-9.]+)"/.exec(xml)?.[1] ?? height
  const paths = [...xml.matchAll(/<path\b([^/>]*)\/?>/g)].map((match) => {
    const attrs = match[1]
    const d = attr(attrs, "pathData")
    const fill = attr(attrs, "fillColor")
    const stroke = attr(attrs, "strokeColor")
    const strokeWidth = attr(attrs, "strokeWidth")
    const cap = attr(attrs, "strokeLineCap")
    const parts = [`d="${escapeAttr(d)}"`]
    parts.push(fill && fill !== "#00000000" ? `fill="${fill}"` : `fill="none"`)
    if (stroke) parts.push(`stroke="${stroke}"`)
    if (strokeWidth) parts.push(`stroke-width="${strokeWidth}"`)
    if (cap) parts.push(`stroke-linecap="${cap}"`)
    return `<path ${parts.join(" ")}/>`
  })
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${vw} ${vh}">${paths.join("")}</svg>`
}

function attr(source: string, name: string): string {
  return new RegExp(`android:${name}="([^"]*)"`).exec(source)?.[1] ?? ""
}

function escapeAttr(value: string): string {
  return value.replace(/&/g, "&amp;").replace(/"/g, "&quot;")
}

export default defineConfig({
  plugins: [clientAssets()],
  server: {
    port: 5174,
    proxy: {
      "/api": "http://127.0.0.1:8080",
    },
  },
  preview: {
    port: 5174,
    proxy: {
      "/api": "http://127.0.0.1:8080",
    },
  },
})
