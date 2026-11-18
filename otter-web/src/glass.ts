export type GlassStyleName = "regular" | "clear"

export type GlassAppearance = {
  refraction: number
  dispersion: number
  bevel: number
  frost: number
  shadow: number
  tint: [number, number, number, number]
}

const VERT = `
precision highp float;
attribute vec2 aPos;
uniform vec2 uSize;
varying vec2 vPx;
void main() {
  vPx = vec2(aPos.x, 1.0 - aPos.y) * uSize;
  gl_Position = vec4(aPos * 2.0 - 1.0, 0.0, 1.0);
}
`

const FRAG = `
precision highp float;
varying vec2 vPx;
uniform sampler2D uContent;
uniform vec2 uOrigin;
uniform vec2 uSize;
uniform float uRadius;
uniform float uRefraction;
uniform float uDispersion;
uniform float uBevel;
uniform float uFrost;
uniform vec4 uRoom;
uniform vec2 uMapOrigin;
uniform vec2 uMapScale;
uniform vec2 uTexSize;
uniform vec4 uTint;

float roundRect(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + vec2(r);
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec2 glassUv(vec2 p) {
  vec2 lo = uOrigin - vec2(uRoom.x, uRoom.y);
  vec2 hi = uOrigin + uSize + vec2(uRoom.z, uRoom.w);
  p = clamp(p, lo, hi);
  return (uMapOrigin + p * uMapScale) / uTexSize;
}

void main() {
  vec2 coord = uOrigin + vPx;
  vec2 halfSize = uSize * 0.5;
  vec2 center = uOrigin + halfSize;
  vec2 p = coord - center;
  float r = min(uRadius, min(halfSize.x, halfSize.y));
  float d = roundRect(p, halfSize, r);
  float dx = roundRect(p + vec2(1.0, 0.0), halfSize, r) - roundRect(p - vec2(1.0, 0.0), halfSize, r);
  float dy = roundRect(p + vec2(0.0, 1.0), halfSize, r) - roundRect(p - vec2(0.0, 1.0), halfSize, r);
  vec2 n = vec2(dx, dy);
  float nLen = length(n);
  n = nLen > 0.001 ? n / nLen : vec2(0.0, -1.0);
  float distIn = max(-d, 0.0);
  float t = clamp(distIn / max(uBevel, 1.0), 0.0, 1.0);
  float rim = pow(1.0 - t, 1.5);
  vec2 bent = coord + n * uRefraction * rim;
  float spread = uRefraction * uDispersion * rim;
  vec4 color = texture2D(uContent, glassUv(bent));
  color.r = texture2D(uContent, glassUv(bent + n * spread)).r;
  color.b = texture2D(uContent, glassUv(bent - n * spread)).b;
  float blur = uFrost * t;
  if (blur > 0.8) {
    vec4 acc = color;
    acc += texture2D(uContent, glassUv(bent + vec2(blur, 0.0)));
    acc += texture2D(uContent, glassUv(bent + vec2(-blur, 0.0)));
    acc += texture2D(uContent, glassUv(bent + vec2(0.0, blur)));
    acc += texture2D(uContent, glassUv(bent + vec2(0.0, -blur)));
    color = acc * 0.2;
  }
  float sky = clamp(-n.y, 0.0, 1.0);
  float ground = clamp(n.y, 0.0, 1.0);
  float hair = smoothstep(3.2, 0.4, distIn) * sky;
  color.rgb = mix(color.rgb, vec3(1.0), hair * 0.55);
  float sole = smoothstep(7.0, 0.6, distIn) * ground;
  color.rgb *= 1.0 - sole * 0.16;
  color.rgb = mix(color.rgb, uTint.rgb, uTint.a);
  color.a = 1.0;
  gl_FragColor = color;
}
`

const images = new Map<string, Promise<HTMLImageElement | null>>()
const live = new Set<GlassPane>()
let pump = 0

export function glassAppearance(
  style: GlassStyleName,
  tint: string | undefined,
  density = 1
): GlassAppearance {
  const clear = style === "clear"
  return {
    refraction: (clear ? 18 : 12) * density,
    dispersion: clear ? 0.22 : 0.1,
    bevel: (clear ? 24 : 16) * density,
    frost: (clear ? 0 : 6) * density,
    shadow: (clear ? 2 : 6) * density,
    tint: parseGlassColor(tint, clear),
  }
}

export function parseGlassColor(raw: string | undefined, clear: boolean): [number, number, number, number] {
  const fallback: [number, number, number, number] = clear ? [1, 1, 1, 0x0a / 255] : [1, 1, 1, 0x2e / 255]
  if (!raw || raw === "transparent") {
    return raw === "transparent" ? [0, 0, 0, 0] : fallback
  }
  const text = raw.trim()
  if (!text.startsWith("#")) return fallback
  const hex = text.slice(1)
  const expand = (value: string) => value.split("").map((char) => char + char).join("")
  const body = hex.length === 3 || hex.length === 4 ? expand(hex) : hex
  if (body.length !== 6 && body.length !== 8) return fallback
  const nums = body.match(/../g)?.map((pair) => parseInt(pair, 16) / 255)
  if (!nums || nums.some((item) => Number.isNaN(item))) return fallback
  if (body.length === 6) return [nums[0], nums[1], nums[2], 1]
  return [nums[1], nums[2], nums[3], nums[0]]
}

export function mountGlass(host: HTMLElement): void {
  if (host.querySelector(":scope > .otter-glass-layer")) return
  const canvas = document.createElement("canvas")
  canvas.className = "otter-glass-layer"
  host.insertBefore(canvas, host.firstChild)
  const pane = new GlassPane(host, canvas)
  live.add(pane)
  if (!pump) pump = requestAnimationFrame(tick)
  if (host.dataset.glassInteractive === "true") {
    host.addEventListener("pointerdown", pane.down)
    host.addEventListener("pointerup", pane.up)
    host.addEventListener("pointerleave", pane.up)
    host.addEventListener("pointercancel", pane.up)
  }
}

function tick() {
  pump = requestAnimationFrame(tick)
  for (const pane of live) {
    try {
      pane.paint()
    } catch (error) {
      pane.mark(error)
    }
  }
  if (live.size === 0 && pump) {
    cancelAnimationFrame(pump)
    pump = 0
  }
}

class GlassPane {
  private gl: WebGLRenderingContext | null = null
  private program: WebGLProgram | null = null
  private texture: WebGLTexture | null = null
  private quad: WebGLBuffer | null = null
  private source = ""
  private signature = ""
  private generation = 0
  private mounted = false
  mark(error: unknown) {
    this.canvas.dataset.glassError = error instanceof Error ? error.message : String(error)
  }

  readonly down = () => {
    this.host.classList.add("pressed")
    this.signature = ""
  }
  readonly up = () => {
    this.host.classList.remove("pressed")
    this.signature = ""
  }

  constructor(
    private readonly host: HTMLElement,
    private readonly canvas: HTMLCanvasElement
  ) {}

  paint() {
    if (!this.host.isConnected) {
      if (!this.mounted) return
      this.dispose()
      live.delete(this)
      return
    }
    this.mounted = true
    const width = this.host.clientWidth
    const height = this.host.clientHeight
    if (width <= 0 || height <= 0) return
    const backdrop = findBackdrop(this.host)
    const style = this.host.dataset.glassStyle === "clear" ? "clear" : "regular"
    const look = glassAppearance(style, this.host.dataset.glassTint || undefined, readDensity(this.host))
    const pressed = this.host.classList.contains("pressed")
    const boost = pressed ? 1.28 : 1
    const tint: [number, number, number, number] = [
      look.tint[0],
      look.tint[1],
      look.tint[2],
      Math.min(1, look.tint[3] * boost),
    ]
    const placed = backdrop ? placement(this.host, backdrop) : null
    const key = [
      width,
      height,
      style,
      tint.join(","),
      look.refraction * boost,
      placed?.key ?? "flat",
      this.source,
    ].join("|")
    if (key === this.signature) return
    this.signature = key
    const generation = ++this.generation
    if (!placed) {
      paintFlat(this.canvas, look, tint)
      return
    }
    void this.paintLens(placed, width, height, look, tint, boost, generation)
  }

  private async paintLens(
    placed: BackdropPlacement,
    width: number,
    height: number,
    look: GlassAppearance,
    tint: [number, number, number, number],
    boost: number,
    generation: number
  ) {
    try {
    const image = await loadImage(placed.url)
    if (generation !== this.generation || !this.host.isConnected || !image) {
      if (generation === this.generation) {
        this.canvas.dataset.glassError = image ? "stale" : "image"
        paintFlat(this.canvas, look, tint)
      }
      return
    }
    this.canvas.dataset.glassError = ""
    if (this.source !== placed.url) {
      this.source = placed.url
      this.upload(image)
    }
    const gl = this.ensure(image)
    if (!gl || !this.program) {
      this.canvas.dataset.glassError = "webgl"
      paintFlat(this.canvas, look, tint)
      return
    }
    this.canvas.style.background = ""
    this.canvas.style.backdropFilter = ""
    const dpr = Math.min(window.devicePixelRatio || 1, 2)
    const nextW = Math.round(width * dpr)
    const nextH = Math.round(height * dpr)
    if (this.canvas.width !== nextW || this.canvas.height !== nextH) {
      this.canvas.width = nextW
      this.canvas.height = nextH
    }
    gl.viewport(0, 0, this.canvas.width, this.canvas.height)
    gl.useProgram(this.program)
    gl.bindTexture(gl.TEXTURE_2D, this.texture)
    gl.bindBuffer(gl.ARRAY_BUFFER, this.quad)
    const loc = gl.getAttribLocation(this.program, "aPos")
    gl.enableVertexAttribArray(loc)
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0)
    const map = imageMap(placed.backdrop, image)
    const roomLeft = Math.max(0, placed.originX)
    const roomTop = Math.max(0, placed.originY)
    const roomRight = Math.max(0, placed.backdropWidth - placed.originX - width)
    const roomBottom = Math.max(0, placed.backdropHeight - placed.originY - height)
    set2(gl, this.program, "uSize", width, height)
    set2(gl, this.program, "uOrigin", placed.originX, placed.originY)
    set1(gl, this.program, "uRadius", Number(this.host.dataset.glassRadius || 0))
    set1(gl, this.program, "uRefraction", look.refraction * boost)
    set1(gl, this.program, "uDispersion", look.dispersion)
    set1(gl, this.program, "uBevel", look.bevel)
    set1(gl, this.program, "uFrost", look.frost)
    set4(gl, this.program, "uRoom", roomLeft, roomTop, roomRight, roomBottom)
    set2(gl, this.program, "uMapOrigin", map.originX, map.originY)
    set2(gl, this.program, "uMapScale", map.scaleX, map.scaleY)
    set2(gl, this.program, "uTexSize", image.naturalWidth, image.naturalHeight)
    set4(gl, this.program, "uTint", tint[0], tint[1], tint[2], tint[3])
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
    } catch (error) {
      this.mark(error)
      paintFlat(this.canvas, look, tint)
    }
  }

  private ensure(image: HTMLImageElement): WebGLRenderingContext | null {
    if (this.gl && this.program) return this.gl
    const gl = this.canvas.getContext("webgl", { antialias: true, preserveDrawingBuffer: true, premultipliedAlpha: false })
    if (!gl) return null
    const program = link(gl, VERT, FRAG)
    if (!program) return null
    this.gl = gl
    this.program = program
    this.quad = gl.createBuffer()
    gl.bindBuffer(gl.ARRAY_BUFFER, this.quad)
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([0, 0, 1, 0, 0, 1, 1, 1]), gl.STATIC_DRAW)
    this.upload(image)
    return gl
  }

  private upload(image: HTMLImageElement) {
    const gl = this.gl
    if (!gl) return
    const texture = this.texture ?? gl.createTexture()
    this.texture = texture
    gl.bindTexture(gl.TEXTURE_2D, texture)
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, 0)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image)
  }

  private dispose() {
    this.host.removeEventListener("pointerdown", this.down)
    this.host.removeEventListener("pointerup", this.up)
    this.host.removeEventListener("pointerleave", this.up)
    this.host.removeEventListener("pointercancel", this.up)
    const gl = this.gl
    if (gl) {
      if (this.texture) gl.deleteTexture(this.texture)
      if (this.quad) gl.deleteBuffer(this.quad)
      if (this.program) gl.deleteProgram(this.program)
      gl.getExtension("WEBGL_lose_context")?.loseContext()
    }
    this.gl = null
  }
}

type BackdropPlacement = {
  backdrop: HTMLElement
  url: string
  originX: number
  originY: number
  backdropWidth: number
  backdropHeight: number
  key: string
}

function findBackdrop(host: HTMLElement): { element: HTMLElement; url: string } | null {
  let node: HTMLElement | null = host.parentElement
  while (node) {
    const image = getComputedStyle(node).backgroundImage
    const url = imageUrl(image)
    if (url) return { element: node, url }
    node = node.parentElement
  }
  return null
}

function placement(host: HTMLElement, found: { element: HTMLElement; url: string }): BackdropPlacement {
  const backdrop = found.element
  const hostBox = host.getBoundingClientRect()
  const backBox = backdrop.getBoundingClientRect()
  const originX = hostBox.left - backBox.left
  const originY = hostBox.top - backBox.top
  const position = getComputedStyle(backdrop).backgroundPosition
  return {
    backdrop,
    url: found.url,
    originX,
    originY,
    backdropWidth: backBox.width,
    backdropHeight: backBox.height,
    key: `${originX.toFixed(1)},${originY.toFixed(1)},${backBox.width.toFixed(1)},${position}`,
  }
}

function imageMap(backdrop: HTMLElement, image: HTMLImageElement) {
  const style = getComputedStyle(backdrop)
  const areaW = backdrop.clientWidth
  const areaH = backdrop.clientHeight
  const size = style.backgroundSize.split(/\s+/)
  let bgW = areaW
  let bgH = areaH
  if (style.backgroundSize === "cover") {
    const scale = Math.max(areaW / image.naturalWidth, areaH / image.naturalHeight)
    bgW = image.naturalWidth * scale
    bgH = image.naturalHeight * scale
  } else {
    bgW = cssLength(size[0], areaW, areaW)
    bgH = !size[1] || size[1] === "auto" ? image.naturalHeight * (bgW / image.naturalWidth) : cssLength(size[1], areaH, areaH)
  }
  const pos = style.backgroundPosition.split(/\s+/)
  const posX = cssPosition(pos[0] ?? "0px", areaW, bgW)
  const posY = cssPosition(pos[1] ?? "0px", areaH, bgH)
  return {
    originX: -posX * (image.naturalWidth / bgW),
    originY: -posY * (image.naturalHeight / bgH),
    scaleX: image.naturalWidth / bgW,
    scaleY: image.naturalHeight / bgH,
  }
}

function cssLength(token: string, area: number, auto: number): number {
  if (token === "auto") return auto
  if (token.endsWith("%")) return (area * parseFloat(token)) / 100
  return parseFloat(token)
}

function cssPosition(token: string, area: number, image: number): number {
  if (token === "left" || token === "top") return 0
  if (token === "right" || token === "bottom") return area - image
  if (token === "center") return (area - image) / 2
  if (token.endsWith("%")) return ((area - image) * parseFloat(token)) / 100
  return parseFloat(token)
}

function imageUrl(value: string): string {
  const match = /url\((['"]?)(.*?)\1\)/.exec(value)
  return match?.[2] ?? ""
}

function loadImage(url: string): Promise<HTMLImageElement | null> {
  const cached = images.get(url)
  if (cached) return cached
  const pending = new Promise<HTMLImageElement | null>((resolve) => {
    const image = new Image()
    image.onload = () => resolve(image.naturalWidth > 0 ? image : null)
    image.onerror = () => {
      images.delete(url)
      resolve(null)
    }
    image.src = url
  })
  images.set(url, pending)
  return pending
}

function paintFlat(canvas: HTMLCanvasElement, look: GlassAppearance, tint: [number, number, number, number]) {
  const [r, g, b, a] = tint
  canvas.style.background = `rgba(${Math.round(r * 255)}, ${Math.round(g * 255)}, ${Math.round(b * 255)}, ${a})`
  canvas.style.backdropFilter = look.frost > 0 ? `blur(${look.frost}px)` : "none"
  canvas.style.setProperty("-webkit-backdrop-filter", canvas.style.backdropFilter)
}

function readDensity(host: HTMLElement): number {
  const raw = host.dataset.glassDensity
  const value = raw ? Number(raw) : 1
  return Number.isFinite(value) && value > 0 ? value : 1
}

function link(gl: WebGLRenderingContext, vert: string, frag: string): WebGLProgram | null {
  const program = gl.createProgram()
  if (!program) return null
  const vs = shader(gl, gl.VERTEX_SHADER, vert)
  const fs = shader(gl, gl.FRAGMENT_SHADER, frag)
  if (!vs || !fs) return null
  gl.attachShader(program, vs)
  gl.attachShader(program, fs)
  gl.linkProgram(program)
  gl.deleteShader(vs)
  gl.deleteShader(fs)
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    throw new Error(gl.getProgramInfoLog(program) || "link")
  }
  return program
}

function shader(gl: WebGLRenderingContext, type: number, source: string): WebGLShader | null {
  const item = gl.createShader(type)
  if (!item) return null
  gl.shaderSource(item, source)
  gl.compileShader(item)
  if (!gl.getShaderParameter(item, gl.COMPILE_STATUS)) {
    const log = gl.getShaderInfoLog(item) || "shader"
    gl.deleteShader(item)
    throw new Error(log)
  }
  return item
}

function set1(gl: WebGLRenderingContext, program: WebGLProgram, name: string, value: number) {
  gl.uniform1f(gl.getUniformLocation(program, name), value)
}

function set2(gl: WebGLRenderingContext, program: WebGLProgram, name: string, x: number, y: number) {
  gl.uniform2f(gl.getUniformLocation(program, name), x, y)
}

function set4(gl: WebGLRenderingContext, program: WebGLProgram, name: string, x: number, y: number, z: number, w: number) {
  gl.uniform4f(gl.getUniformLocation(program, name), x, y, z, w)
}
