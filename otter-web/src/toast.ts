let timer = 0

export function showToast(message: string) {
  const text = message.trim()
  if (!text) return
  let el = document.querySelector<HTMLElement>(".otter-toast")
  if (!el) {
    el = document.createElement("div")
    el.className = "otter-toast"
    document.body.appendChild(el)
  }
  el.textContent = text
  window.clearTimeout(timer)
  timer = window.setTimeout(() => el?.remove(), 2200)
}
