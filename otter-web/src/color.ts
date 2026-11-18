export function cssColor(value: string): string {
  if (value === "transparent") {
    return "transparent"
  }
  const eight = /^#([0-9a-fA-F]{8})$/.exec(value)
  if (eight) {
    const hex = eight[1]
    return `#${hex.slice(2)}${hex.slice(0, 2)}`
  }
  return value
}

export function cssBackground(value: string): string {
  if (value.startsWith("linear-gradient")) {
    return value.replace(/#([0-9a-fA-F]{8})/g, (hex) => cssColor(hex))
  }
  if (value.startsWith("res:")) {
    return value
  }
  return cssColor(value)
}
