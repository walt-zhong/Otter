import { ExpansionCenter } from "./expansion"
import { PageStack } from "./page-stack"
import { showToast } from "./toast"
import type { JsonObject } from "./types"

export const PermissionCapability = {
  CAMERA: "camera",
  MICROPHONE: "microphone",
  LOCATION_WHEN_IN_USE: "location.whenInUse",
  PHOTOS: "photos",
  NOTIFICATIONS: "notifications",
} as const

const PREFIX: Record<string, string> = {
  camera: "camera",
  microphone: "microphone",
  "location.whenInUse": "location",
  photos: "photos",
  notifications: "notifications",
}

export type PermissionPrompt = { title: string; message: string }

export type PermissionResult = {
  capability: string
  status: string
  canAskAgain: boolean
  asked: boolean
  detail: string
}

const GRANTED = "granted"
const DENIED = "denied"
const PERMANENT = "permanentlyDenied"
const UNSUPPORTED = "unsupported"
const PROMPT = "prompt"

export function permissionPrompts(): Record<string, PermissionPrompt> {
  return {
    camera: { title: "相机", message: "用来拍照。接下来会弹出系统对话框，你可以拒绝。" },
    microphone: { title: "麦克风", message: "用来录音。接下来会弹出系统对话框，你可以拒绝。" },
    "location.whenInUse": {
      title: "位置",
      message: "只在使用时获取位置，不会在后台定位。你可以只给大致位置。",
    },
    photos: {
      title: "相册",
      message: "接下来打开系统选图。只会拿到你选中的那张，不会读取整个相册。",
    },
    notifications: { title: "通知", message: "用来发送通知。接下来会弹出系统对话框，你可以拒绝。" },
  }
}

const remembered = new Map<string, PermissionResult>()

export class PermissionCenter {
  private constructor(private prompts: Record<string, PermissionPrompt>) {}

  static install(prompts: Record<string, PermissionPrompt>): PermissionCenter {
    const center = new PermissionCenter(prompts)
    ExpansionCenter.registerHostAction("permissionCheck", (params) => {
      void center.one(params, "check")
    })
    ExpansionCenter.registerHostAction("permissionRequest", (params) => {
      void center.one(params, "request")
    })
    ExpansionCenter.registerHostAction("permissionOpenSettings", (params) => {
      void center.one(params, "settings")
    })
    return center
  }

  check(capability: string): PermissionResult {
    return remembered.get(capability) ?? unknown(capability)
  }

  async request(capability: string): Promise<PermissionResult> {
    const prompt = this.prompts[capability]
    if (prompt) {
      const accepted = await confirmBox(prompt.title, prompt.message)
      if (!accepted) return this.check(capability)
    }
    const result = await requestSystem(capability)
    remembered.set(capability, result)
    return result
  }

  async openSettings(capability: string): Promise<PermissionResult> {
    showToast("请到浏览器的网站设置里打开这项")
    const result = await querySystem(capability)
    remembered.set(capability, result)
    return result
  }

  private async one(params: JsonObject | undefined, mode: "check" | "request" | "settings") {
    const capability = typeof params?.capability === "string" ? params.capability : ""
    if (!PREFIX[capability]) {
      showToast("没有这项能力")
      return
    }
    const result =
      mode === "check" ? await querySystem(capability) : mode === "request" ? await this.request(capability) : await this.openSettings(capability)
    remembered.set(capability, result)
    publish(result)
  }
}

export async function publishAll() {
  const results = await Promise.all(Object.keys(PREFIX).map((item) => querySystem(item)))
  const stack = PageStack.current
  if (!stack) return
  stack.editCurrentData((data) => {
    for (const result of results) writeResult(data, result)
  })
  stack.rebindCurrent()
}

function publish(result: PermissionResult) {
  const stack = PageStack.current
  if (!stack) {
    showToast("这个页面还接不上")
    return
  }
  stack.editCurrentData((data) => writeResult(data, result))
  stack.rebindCurrent()
}

function writeResult(data: JsonObject, result: PermissionResult) {
  const key = PREFIX[result.capability]
  if (!key) return
  data[`${key}Status`] = result.status
  data[`${key}StatusText`] = statusText(result)
  data[`${key}ShowSettings`] = result.status === PERMANENT || (result.status === DENIED && !result.canAskAgain)
  if (result.capability === PermissionCapability.PHOTOS && result.detail.startsWith("blob:")) {
    data.photoSrc = result.detail
    data.avatar = result.detail
    data.photoVisible = true
  }
}

function statusText(result: PermissionResult): string {
  if (result.capability === PermissionCapability.PHOTOS) {
    if (result.status === GRANTED) return "已选好一张"
    if (result.status === UNSUPPORTED) return "当前版本没有这项"
    return result.asked ? "没有选图片" : "还没选过"
  }
  if (result.capability === PermissionCapability.LOCATION_WHEN_IN_USE) {
    if (result.status === GRANTED) return "已允许，精确位置"
    if (result.status === PERMANENT) return "已关闭，要到系统设置里打开"
    if (result.status === UNSUPPORTED) return "当前版本没有这项"
    return result.asked ? "未允许" : "还没问过"
  }
  if (result.status === GRANTED) return "已允许"
  if (result.status === PERMANENT) return "已关闭，要到系统设置里打开"
  if (result.status === UNSUPPORTED) return "当前版本没有这项"
  return result.asked ? "未允许" : "还没问过"
}

function unknown(capability: string): PermissionResult {
  return { capability, status: PROMPT, canAskAgain: true, asked: false, detail: "" }
}

async function querySystem(capability: string): Promise<PermissionResult> {
  const saved = remembered.get(capability)
  if (capability === PermissionCapability.PHOTOS) {
    return saved ?? unknown(capability)
  }
  if (capability === PermissionCapability.NOTIFICATIONS) {
    if (typeof Notification === "undefined") return unsupported(capability)
    const state = Notification.permission
    return {
      capability,
      status: state === "granted" ? GRANTED : state === "denied" ? PERMANENT : PROMPT,
      canAskAgain: state !== "denied",
      asked: state !== "default",
      detail: "",
    }
  }
  const name = permissionName(capability)
  if (!name || !navigator.permissions?.query) return saved ?? unknown(capability)
  try {
    const status = await navigator.permissions.query({ name })
    const mapped = status.state === "granted" ? GRANTED : status.state === "denied" ? PERMANENT : PROMPT
    return {
      capability,
      status: mapped,
      canAskAgain: status.state !== "denied",
      asked: status.state !== "prompt",
      detail: saved?.detail ?? "",
    }
  } catch {
    return saved ?? unknown(capability)
  }
}

async function requestSystem(capability: string): Promise<PermissionResult> {
  try {
    if (capability === PermissionCapability.CAMERA || capability === PermissionCapability.MICROPHONE) {
      if (!navigator.mediaDevices?.getUserMedia) return unsupported(capability)
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: capability === PermissionCapability.MICROPHONE,
        video: capability === PermissionCapability.CAMERA,
      })
      stream.getTracks().forEach((track) => track.stop())
      return { capability, status: GRANTED, canAskAgain: true, asked: true, detail: "" }
    }
    if (capability === PermissionCapability.LOCATION_WHEN_IN_USE) {
      if (!navigator.geolocation) return unsupported(capability)
      await new Promise<GeolocationPosition>((resolve, reject) => {
        navigator.geolocation.getCurrentPosition(resolve, reject, { enableHighAccuracy: true, timeout: 8000 })
      })
      return { capability, status: GRANTED, canAskAgain: true, asked: true, detail: "" }
    }
    if (capability === PermissionCapability.NOTIFICATIONS) {
      if (typeof Notification === "undefined") return unsupported(capability)
      const state = await Notification.requestPermission()
      return {
        capability,
        status: state === "granted" ? GRANTED : PERMANENT,
        canAskAgain: state !== "denied",
        asked: true,
        detail: "",
      }
    }
    if (capability === PermissionCapability.PHOTOS) {
      const url = await pickImage()
      if (!url) {
        return { capability, status: PROMPT, canAskAgain: true, asked: true, detail: "" }
      }
      return { capability, status: GRANTED, canAskAgain: true, asked: true, detail: url }
    }
  } catch {
    return { capability, status: PERMANENT, canAskAgain: false, asked: true, detail: "" }
  }
  return unsupported(capability)
}

function unsupported(capability: string): PermissionResult {
  return { capability, status: UNSUPPORTED, canAskAgain: false, asked: false, detail: "" }
}

function permissionName(capability: string): PermissionName | null {
  if (capability === PermissionCapability.CAMERA) return "camera"
  if (capability === PermissionCapability.MICROPHONE) return "microphone"
  if (capability === PermissionCapability.LOCATION_WHEN_IN_USE) return "geolocation"
  return null
}

function pickImage(): Promise<string | null> {
  return new Promise((resolve) => {
    const input = document.createElement("input")
    input.type = "file"
    input.accept = "image/*"
    input.addEventListener("change", () => {
      const file = input.files?.[0]
      resolve(file ? URL.createObjectURL(file) : null)
    })
    input.addEventListener("cancel", () => resolve(null))
    input.click()
  })
}

function confirmBox(title: string, message: string): Promise<boolean> {
  return new Promise((resolve) => {
    const mask = document.createElement("div")
    mask.style.cssText =
      "position:fixed;inset:0;background:rgba(31,26,23,.35);display:flex;align-items:center;justify-content:center;z-index:40;padding:24px;"
    const card = document.createElement("div")
    card.style.cssText = "width:min(320px,100%);background:#FFFCF8;border-radius:16px;padding:20px;color:#1F1A17;"
    const heading = document.createElement("div")
    heading.textContent = title
    heading.style.cssText = "font-size:17px;font-weight:600;"
    const body = document.createElement("div")
    body.textContent = message
    body.style.cssText = "margin-top:8px;font-size:14px;line-height:1.5;color:#5c564f;"
    const row = document.createElement("div")
    row.style.cssText = "display:flex;justify-content:flex-end;gap:12px;margin-top:18px;"
    const cancel = button("取消", false)
    const ok = button("继续", true)
    cancel.onclick = () => {
      mask.remove()
      resolve(false)
    }
    ok.onclick = () => {
      mask.remove()
      resolve(true)
    }
    row.append(cancel, ok)
    card.append(heading, body, row)
    mask.appendChild(card)
    document.body.appendChild(mask)
  })
}

function button(label: string, primary: boolean): HTMLButtonElement {
  const el = document.createElement("button")
  el.type = "button"
  el.textContent = label
  el.style.cssText = primary
    ? "border:0;background:#8B572A;color:#fff;border-radius:10px;padding:8px 14px;font:inherit;"
    : "border:0;background:transparent;color:#8A8178;padding:8px 14px;font:inherit;"
  return el
}
