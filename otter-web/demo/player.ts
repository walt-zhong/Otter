import type { JsonObject } from "../src/types"
import type { TemplateView } from "../src/view"

const playing = { titleColor: "#F2C14E", rowBg: "#3A2A22", mark: "正在听" }
const idle = { titleColor: "#F6F1EA", rowBg: "#241F1C", mark: "" }

export function attachPlayer(view: TemplateView): () => void {
  const tracks = Array.isArray(view.data.tracks) ? (view.data.tracks.filter(isObject) as JsonObject[]) : []
  let index = 0
  let playingNow = true
  let scrubbing = false
  let position = 0
  const timer = window.setInterval(() => {
    if (!playingNow || scrubbing) return
    position += 500
    if (position >= duration(index)) show((index + 1) % Math.max(tracks.length, 1), true)
    else renderClock()
  }, 500)

  const seek = view.element("seek")
  seek?.addEventListener("pointerdown", (event) => {
    scrubbing = true
    move(event)
    const end = () => {
      scrubbing = false
    }
    window.addEventListener("pointerup", end, { once: true })
  })
  seek?.addEventListener("pointermove", (event) => {
    if (scrubbing) move(event)
  })

  view.element("playToggle")?.addEventListener("click", () => {
    playingNow = !playingNow
    renderTransport()
  })
  view.element("playPrev")?.addEventListener("click", () => show(index - 1, true))
  view.element("playNext")?.addEventListener("click", () => show(index + 1, true))
  view.element("queue")?.addEventListener("click", (event) => {
    const row = event.target instanceof Element ? event.target.closest(".otter-item") : null
    const queue = view.element("queue")
    if (!row || !queue) return
    const next = [...queue.children].indexOf(row)
    if (next >= 0) show(next, true)
  })

  position = 0.36 * duration(0)
  renderClock()
  renderTransport()

  function move(event: PointerEvent) {
    const bounds = seek?.getBoundingClientRect()
    if (!bounds || bounds.width <= 0) return
    const fraction = Math.min(1, Math.max(0, (event.clientX - bounds.left) / bounds.width))
    position = fraction * duration(index)
    renderClock()
  }

  function show(raw: number, reset: boolean) {
    if (tracks.length === 0) return
    const next = ((raw % tracks.length) + tracks.length) % tracks.length
    const previous = index
    index = next
    if (reset) {
      position = 0
      playingNow = true
    }
    const track = tracks[index]
    view.setImage("cover", String(track.cover ?? ""))
    view.setText("trackTitle", String(track.title ?? ""), null)
    view.setText("trackArtist", String(track.artist ?? ""), null)
    view.setText("duration", String(track.length ?? ""), null)
    if (previous !== index) {
      view.patchListItem("queue", previous, idle)
      view.patchListItem("queue", index, playing)
      view.element("queue")?.children[index]?.scrollIntoView({ block: "nearest" })
    }
    renderTransport()
    renderClock()
  }

  function renderTransport() {
    view.setImage("playToggle", playingNow ? "res:ic_player_pause" : "res:ic_player_play")
    view.setText("playState", playingNow ? "正在播放" : "已暂停", null)
    view.setLottiePlaying("meter", playingNow)
  }

  function renderClock() {
    const length = duration(index)
    if (position > length) position = length
    view.setText("elapsed", format(position), null)
    view.setProgress("seek", length === 0 ? 0 : position / length)
  }

  function duration(at: number): number {
    const parts = String(tracks[at]?.length ?? "0:01").split(":")
    const minutes = Number(parts[0] ?? 0)
    const seconds = Number(parts[1] ?? 0)
    return Math.max(1000, (minutes * 60 + seconds) * 1000)
  }

  return () => window.clearInterval(timer)
}

function format(ms: number): string {
  const total = Math.floor(ms / 1000)
  const minutes = Math.floor(total / 60)
  const seconds = total % 60
  return `${minutes}:${String(seconds).padStart(2, "0")}`
}

function isObject(value: unknown): value is JsonObject {
  return value != null && typeof value === "object" && !Array.isArray(value)
}
