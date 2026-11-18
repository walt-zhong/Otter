import { verifyAsync } from "@noble/ed25519"
import { parseRoutes } from "./routes"
import { parseTemplate } from "./parser"
import { TemplateParseException } from "./types"

const NAMES = [
  "routes.json",
  "templates/list.json",
  "templates/detail.json",
  "data/list.json",
  "data/detail.json",
  "manifest.json",
]
const CONTENT = NAMES.slice(0, -1)
const MANIFEST_KEYS = ["id", "intent", "sample", "createdAt", "hash", "alg", "signature"]
const MAX_FILE = 256 * 1024
const MAX_ZIP = 1024 * 1024
const slotPattern = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/
const idPattern = /^[A-Za-z0-9][A-Za-z0-9._-]{0,80}$/

export const BundleFailure = {
  NETWORK: "NETWORK",
  PUBLIC_KEY: "PUBLIC_KEY",
  TOO_LARGE: "TOO_LARGE",
  LAYOUT: "LAYOUT",
  MANIFEST: "MANIFEST",
  DIGEST: "DIGEST",
  SIGNATURE: "SIGNATURE",
  PARSE: "PARSE",
  PATH: "PATH",
  IO: "IO",
} as const

export type BundleFailureName = (typeof BundleFailure)[keyof typeof BundleFailure]

export class BundleException extends Error {
  readonly failure: BundleFailureName

  constructor(failure: BundleFailureName, message: string, options?: { cause?: unknown }) {
    super(message, options)
    this.name = "BundleException"
    this.failure = failure
  }
}

export type BundleDownload = {
  id: string
  zip: Uint8Array
  intent?: string
  sample?: boolean
}

export type InstalledBundle = {
  id: string
  files: Record<string, string>
  origin: "DOWNLOAD" | "CACHE"
  intent: string
  sample: boolean
  fellBack: boolean
  failure: BundleFailureName | null
}

export type BundleRecord = {
  slot: string
  id: string | null
  stage: "FETCH" | "INSTALL"
  success: boolean
  failure: BundleFailureName | null
  origin: "DOWNLOAD" | "CACHE" | null
  fellBack: boolean
  bytes: number
  durationMs: number
  atMs: number
}

type StoredBundle = {
  id: string
  intent: string
  sample: boolean
  files: Record<string, string>
}

export type BundleCache = {
  read(slot: string): Promise<StoredBundle | null>
  write(slot: string, value: StoredBundle): Promise<void>
}

type Listener = (record: BundleRecord) => void

const listeners = new Set<Listener>()
const stats = {
  fetchAttempts: 0,
  fetchSuccess: 0,
  installAttempts: 0,
  installSuccess: 0,
}

export const BundleCenter = {
  addListener(listener: Listener) {
    listeners.add(listener)
  },
  removeListener(listener: Listener) {
    listeners.delete(listener)
  },
  snapshot() {
    return {
      ...stats,
      downloadSuccessRate: rate(stats.fetchSuccess, stats.fetchAttempts),
      usableRate: rate(stats.installSuccess, stats.installAttempts),
    }
  },
  resetSnapshot() {
    stats.fetchAttempts = 0
    stats.fetchSuccess = 0
    stats.installAttempts = 0
    stats.installSuccess = 0
  },
  async current(cache: BundleCache, slot: string, publicKey: Uint8Array): Promise<InstalledBundle | null> {
    checkSlot(slot)
    requireKey(publicKey)
    const stored = await cache.read(slot)
    if (!stored) return null
    try {
      acceptText(stored.files, publicKey, stored)
    } catch {
      return null
    }
    return installed(stored, "CACHE", false, null)
  },
  async install(
    cache: BundleCache,
    slot: string,
    publicKey: Uint8Array,
    zip: Uint8Array,
    fallback: "NONE" | "LAST_VERIFIED" = "LAST_VERIFIED"
  ): Promise<InstalledBundle> {
    checkSlot(slot)
    requireKey(publicKey)
    const started = now()
    try {
      const opened = await openZip(zip, publicKey)
      await cache.write(slot, opened)
      const ready = installed(opened, "DOWNLOAD", false, null)
      this.emit(record(slot, ready.id, "INSTALL", true, null, "DOWNLOAD", false, zip.byteLength, started), true)
      return ready
    } catch (error) {
      const wrapped = asBundle(error)
      return this.recover(cache, slot, publicKey, fallback, wrapped, zip.byteLength, started)
    }
  },
  async load(
    cache: BundleCache,
    slot: string,
    publicKey: Uint8Array,
    fetcher: () => Promise<BundleDownload>,
    fallback: "NONE" | "LAST_VERIFIED" = "LAST_VERIFIED"
  ): Promise<InstalledBundle> {
    checkSlot(slot)
    requireKey(publicKey)
    const fetchStarted = now()
    let downloaded: BundleDownload
    try {
      downloaded = await fetcher()
    } catch (error) {
      const wrapped = error instanceof BundleException ? error : new BundleException(BundleFailure.NETWORK, messageOf(error))
      this.emit(record(slot, null, "FETCH", false, wrapped.failure, null, false, 0, fetchStarted), false)
      return this.recover(cache, slot, publicKey, fallback, wrapped, 0, now())
    }
    this.emit(record(slot, downloaded.id, "FETCH", true, null, null, false, downloaded.zip.byteLength, fetchStarted), false)
    const started = now()
    try {
      const opened = await openZip(downloaded.zip, publicKey)
      if (opened.id !== downloaded.id) throw new BundleException(BundleFailure.MANIFEST, "manifest 无效")
      if (downloaded.intent != null && downloaded.intent !== opened.intent) {
        throw new BundleException(BundleFailure.MANIFEST, "manifest 无效")
      }
      if (downloaded.sample != null && downloaded.sample !== opened.sample) {
        throw new BundleException(BundleFailure.MANIFEST, "manifest 无效")
      }
      await cache.write(slot, opened)
      const ready = installed(opened, "DOWNLOAD", false, null)
      this.emit(record(slot, ready.id, "INSTALL", true, null, "DOWNLOAD", false, downloaded.zip.byteLength, started), true)
      return ready
    } catch (error) {
      const wrapped = asBundle(error)
      return this.recover(cache, slot, publicKey, fallback, wrapped, downloaded.zip.byteLength, started)
    }
  },
  async recover(
    cache: BundleCache,
    slot: string,
    publicKey: Uint8Array,
    fallback: "NONE" | "LAST_VERIFIED",
    error: BundleException,
    bytes: number,
    started: number
  ): Promise<InstalledBundle> {
    if (fallback === "LAST_VERIFIED") {
      const cached = await this.current(cache, slot, publicKey)
      if (cached) {
        const ready = { ...cached, fellBack: true, failure: error.failure, origin: "CACHE" as const }
        this.emit(record(slot, ready.id, "INSTALL", true, error.failure, "CACHE", true, bytes, started), true)
        return ready
      }
    }
    this.emit(record(slot, null, "INSTALL", false, error.failure, null, false, bytes, started), true)
    throw error
  },
  emit(entry: BundleRecord, countInstall: boolean) {
    if (entry.stage === "FETCH") {
      stats.fetchAttempts += 1
      if (entry.success) stats.fetchSuccess += 1
    }
    if (countInstall || entry.stage === "INSTALL") {
      if (entry.stage === "INSTALL") {
        stats.installAttempts += 1
        if (entry.success) stats.installSuccess += 1
      }
    }
    for (const listener of listeners) {
      try {
        listener(entry)
      } catch {
        // 监听器抛错不影响安装
      }
    }
  },
}

export function memoryCache(): BundleCache {
  const slots = new Map<string, StoredBundle>()
  return {
    async read(slot) {
      return slots.get(slot) ?? null
    },
    async write(slot, value) {
      slots.set(slot, value)
    },
  }
}

export function browserCache(): BundleCache {
  return {
    read: (slot) => idb("readonly", (store) => store.get(slot)),
    write: (slot, value) =>
      idb("readwrite", (store) => {
        store.put(value, slot)
      }),
  }
}

async function openZip(raw: Uint8Array, publicKey: Uint8Array): Promise<StoredBundle> {
  if (raw.byteLength > MAX_ZIP) throw new BundleException(BundleFailure.TOO_LARGE, "包太大")
  const files = readStoredZip(raw)
  if (!sameNames(files)) throw new BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定")
  let sum = 0
  for (const name of NAMES) {
    const body = files.get(name)
    if (!body || body.byteLength > MAX_FILE) throw new BundleException(BundleFailure.TOO_LARGE, "文件太大")
    sum += body.byteLength
  }
  if (sum > MAX_ZIP) throw new BundleException(BundleFailure.TOO_LARGE, "包太大")
  const text = Object.fromEntries([...files].map(([name, body]) => [name, new TextDecoder().decode(body)]))
  const opened = await acceptText(text, publicKey)
  return opened
}

async function acceptText(
  files: Record<string, string>,
  publicKey: Uint8Array,
  known?: StoredBundle
): Promise<StoredBundle> {
  if (publicKey.byteLength !== 32) throw new BundleException(BundleFailure.PUBLIC_KEY, "公钥无效")
  if (!sameTextNames(files)) throw new BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定")
  const manifest = parseManifest(files["manifest.json"])
  const digest = await digestFiles(files)
  const hex = [...digest].map((byte) => byte.toString(16).padStart(2, "0")).join("")
  if (hex !== manifest.hash) throw new BundleException(BundleFailure.DIGEST, "摘要不一致")
  let signature: Uint8Array
  try {
    signature = Uint8Array.from(atob(manifest.signature), (char) => char.charCodeAt(0))
  } catch (error) {
    throw new BundleException(BundleFailure.SIGNATURE, "签名无效", { cause: error })
  }
  if (signature.byteLength !== 64 || !(await verifyAsync(signature, digest, publicKey))) {
    throw new BundleException(BundleFailure.SIGNATURE, "签名无效")
  }
  if (!idPattern.test(manifest.id)) throw new BundleException(BundleFailure.MANIFEST, "manifest 无效")
  acceptContent(files)
  const opened = { id: manifest.id, intent: manifest.intent, sample: manifest.sample, files }
  if (known && (known.id !== opened.id || known.intent !== opened.intent || known.sample !== opened.sample)) {
    throw new BundleException(BundleFailure.MANIFEST, "manifest 无效")
  }
  return opened
}

function acceptContent(files: Record<string, string>) {
  let routes
  try {
    routes = parseRoutes(files["routes.json"])
  } catch (error) {
    throw new BundleException(BundleFailure.PARSE, error instanceof Error ? error.message : "路由无法解析", { cause: error })
  }
  const seenTemplates = new Set<string>()
  const seenData = new Set<string>()
  for (const page of Object.values(routes.pages)) {
    acceptTemplate(files, page.template)
    seenTemplates.add(page.template)
    if (page.data) {
      acceptData(files, page.data)
      seenData.add(page.data)
    }
  }
  for (const name of Object.keys(files)) {
    if (name.startsWith("templates/") && !seenTemplates.has(name)) acceptTemplate(files, name)
    if (name.startsWith("data/") && !seenData.has(name)) acceptData(files, name)
  }
}

function acceptTemplate(files: Record<string, string>, path: string) {
  const body = files[path]
  if (body == null || !path.startsWith("templates/")) {
    throw new BundleException(BundleFailure.PARSE, "页面模版不在包内")
  }
  try {
    parseTemplate(body)
  } catch (error) {
    if (error instanceof TemplateParseException) {
      throw new BundleException(BundleFailure.PARSE, error.message, { cause: error })
    }
    throw new BundleException(BundleFailure.PARSE, "模版无法解析", { cause: error })
  }
}

function acceptData(files: Record<string, string>, path: string) {
  const body = files[path]
  if (body == null || !path.startsWith("data/")) {
    throw new BundleException(BundleFailure.PARSE, "页面数据不在包内")
  }
  let parsed: unknown
  try {
    parsed = JSON.parse(body)
  } catch (error) {
    throw new BundleException(BundleFailure.PARSE, "数据不是合法 JSON", { cause: error })
  }
  if (parsed == null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new BundleException(BundleFailure.PARSE, "数据必须是 JSON 对象")
  }
}

async function digestFiles(files: Record<string, string>): Promise<Uint8Array> {
  const parts: Uint8Array[] = []
  const encoder = new TextEncoder()
  for (const name of CONTENT) {
    const body = files[name]
    if (body == null) throw new BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定")
    const bytes = encoder.encode(body)
    parts.push(encoder.encode(name), Uint8Array.of(0x0a), encoder.encode(String(bytes.byteLength)), Uint8Array.of(0x0a), bytes)
  }
  const total = parts.reduce((sum, part) => sum + part.byteLength, 0)
  const buffer = new Uint8Array(total)
  let offset = 0
  for (const part of parts) {
    buffer.set(part, offset)
    offset += part.byteLength
  }
  return new Uint8Array(await crypto.subtle.digest("SHA-256", buffer))
}

function parseManifest(raw: string) {
  let manifest: unknown
  try {
    manifest = JSON.parse(raw)
  } catch (error) {
    throw new BundleException(BundleFailure.MANIFEST, "manifest 无效", { cause: error })
  }
  if (manifest == null || typeof manifest !== "object" || Array.isArray(manifest)) {
    throw new BundleException(BundleFailure.MANIFEST, "manifest 无效")
  }
  const record = manifest as Record<string, unknown>
  const keys = Object.keys(record)
  if (keys.length !== MANIFEST_KEYS.length || MANIFEST_KEYS.some((key) => !keys.includes(key))) {
    throw new BundleException(BundleFailure.MANIFEST, "manifest 无效")
  }
  for (const key of ["id", "intent", "createdAt", "hash", "alg", "signature"]) {
    if (typeof record[key] !== "string" || record[key] === "") {
      throw new BundleException(BundleFailure.MANIFEST, "manifest 无效")
    }
  }
  if (typeof record.sample !== "boolean" || record.alg !== "ed25519") {
    throw new BundleException(BundleFailure.MANIFEST, "manifest 无效")
  }
  return record as {
    id: string
    intent: string
    sample: boolean
    createdAt: string
    hash: string
    alg: string
    signature: string
  }
}

function readStoredZip(raw: Uint8Array): Map<string, Uint8Array> {
  const eocd = findEocd(raw)
  const count = u16(raw, eocd + 10)
  let offset = u32(raw, eocd + 16)
  const out = new Map<string, Uint8Array>()
  for (let index = 0; index < count; index += 1) {
    if (u32(raw, offset) !== 0x02014b50) throw new BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定")
    const madeBy = u16(raw, offset + 4)
    const method = u16(raw, offset + 10)
    const compressed = u32(raw, offset + 20)
    const nameLen = u16(raw, offset + 28)
    const extraLen = u16(raw, offset + 30)
    const commentLen = u16(raw, offset + 32)
    const external = u32(raw, offset + 38)
    const local = u32(raw, offset + 42)
    const nameStart = offset + 46
    const name = new TextDecoder().decode(raw.subarray(nameStart, nameStart + nameLen))
    if (method !== 0) throw new BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定")
    if (madeBy >>> 8 === 3) {
      const mode = (external >>> 16) & 0xffff
      if ((mode & 0x49) !== 0 || (mode & 0xf000) === 0xa000) {
        throw new BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定")
      }
    }
    if (!NAMES.includes(name) || out.has(name)) {
      throw new BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定")
    }
    if (u32(raw, local) !== 0x04034b50) throw new BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定")
    const localName = u16(raw, local + 26)
    const localExtra = u16(raw, local + 28)
    const dataStart = local + 30 + localName + localExtra
    const body = raw.subarray(dataStart, dataStart + compressed)
    if (body.byteLength > MAX_FILE) throw new BundleException(BundleFailure.TOO_LARGE, "文件太大")
    out.set(name, body)
    offset = nameStart + nameLen + extraLen + commentLen
  }
  return out
}

function findEocd(raw: Uint8Array): number {
  const start = Math.max(0, raw.byteLength - 22 - 0xffff)
  for (let index = raw.byteLength - 22; index >= start; index -= 1) {
    if (raw[index] === 0x50 && raw[index + 1] === 0x4b && raw[index + 2] === 0x05 && raw[index + 3] === 0x06) {
      return index
    }
  }
  throw new BundleException(BundleFailure.LAYOUT, "包里的文件不符合约定")
}

function u16(raw: Uint8Array, offset: number): number {
  return raw[offset] | (raw[offset + 1] << 8)
}

function u32(raw: Uint8Array, offset: number): number {
  return (raw[offset] | (raw[offset + 1] << 8) | (raw[offset + 2] << 16) | (raw[offset + 3] << 24)) >>> 0
}

function sameNames(files: Map<string, Uint8Array>): boolean {
  return NAMES.length === files.size && NAMES.every((name) => files.has(name))
}

function sameTextNames(files: Record<string, string>): boolean {
  const keys = Object.keys(files)
  return keys.length === NAMES.length && NAMES.every((name) => keys.includes(name))
}

function installed(
  stored: StoredBundle,
  origin: "DOWNLOAD" | "CACHE",
  fellBack: boolean,
  failure: BundleFailureName | null
): InstalledBundle {
  return {
    id: stored.id,
    files: stored.files,
    origin,
    intent: stored.intent,
    sample: stored.sample,
    fellBack,
    failure,
  }
}

function record(
  slot: string,
  id: string | null,
  stage: "FETCH" | "INSTALL",
  success: boolean,
  failure: BundleFailureName | null,
  origin: "DOWNLOAD" | "CACHE" | null,
  fellBack: boolean,
  bytes: number,
  started: number
): BundleRecord {
  return {
    slot,
    id,
    stage,
    success,
    failure,
    origin,
    fellBack,
    bytes,
    durationMs: Math.round(now() - started),
    atMs: Date.now(),
  }
}

function checkSlot(slot: string) {
  if (!slotPattern.test(slot)) throw new BundleException(BundleFailure.PATH, "路径越界")
}

function requireKey(publicKey: Uint8Array) {
  if (publicKey.byteLength !== 32) throw new BundleException(BundleFailure.PUBLIC_KEY, "公钥无效")
}

function asBundle(error: unknown): BundleException {
  if (error instanceof BundleException) return error
  return new BundleException(BundleFailure.IO, "模版没有写入本地", { cause: error })
}

function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : "请求失败"
}

function rate(hit: number, total: number): number {
  if (total === 0) return 0
  return hit / total
}

function now(): number {
  return performance.now()
}

function idb<T>(mode: IDBTransactionMode, run: (store: IDBObjectStore) => IDBRequest<T> | void): Promise<T> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open("otter-web", 1)
    request.onupgradeneeded = () => {
      const db = request.result
      if (!db.objectStoreNames.contains("bundles")) db.createObjectStore("bundles")
    }
    request.onerror = () => reject(new BundleException(BundleFailure.IO, "模版没有写入本地", { cause: request.error }))
    request.onsuccess = () => {
      const db = request.result
      const tx = db.transaction("bundles", mode)
      const store = tx.objectStore("bundles")
      const result = run(store)
      tx.oncomplete = () => {
        db.close()
        resolve((result && "result" in result ? result.result : undefined) as T)
      }
      tx.onerror = () => {
        db.close()
        reject(new BundleException(BundleFailure.IO, "模版没有写入本地", { cause: tx.error }))
      }
    }
  })
}
