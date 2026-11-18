import {
  TemplateParseException,
  type EventSpec,
  type Json,
  type JsonObject,
  type ParsedNode,
  type ParsedTemplate,
} from "./types"

const MAX_DEPTH = 32
const MAX_NODES = 2000
const namePattern = /^[A-Za-z_][A-Za-z0-9_]*$/
const colorPattern = /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/

const justifyValues: Record<string, string> = {
  start: "start",
  center: "center",
  end: "end",
  spaceBetween: "space-between",
  spaceAround: "space-around",
  spaceEvenly: "space-evenly",
}
const alignValues: Record<string, string> = {
  start: "start",
  center: "center",
  end: "end",
  baseline: "baseline",
  stretch: "stretch",
}
const textAlignValues = new Set(["start", "center", "end"])
const alignSelfValues = new Set(["start", "center", "end", "stretch"])
const fontWeights = new Set(["regular", "medium", "bold"])
const imageFits = new Set(["cover", "contain", "fill"])
const keyboardValues = new Set(["text", "number", "password", "email", "phone"])
const gradientDirections: Record<string, string> = {
  bottom: "to bottom",
  top: "to top",
  left: "to left",
  right: "to right",
  topLeft: "to top left",
  topRight: "to top right",
  bottomLeft: "to bottom left",
  bottomRight: "to bottom right",
}
const viewNames: Record<string, string> = {
  column: "Column",
  row: "Row",
  text: "Text",
  image: "Image",
  spacer: "Spacer",
  list: "OTList",
  progress: "Progress",
  lottie: "Animation",
  input: "Input",
  checkbox: "CheckBox",
  radio: "Radio",
  switch: "Switch",
}

export function parseTemplate(json: string): ParsedTemplate {
  let root: unknown
  try {
    root = JSON.parse(json)
  } catch (error) {
    const message = error instanceof Error ? error.message : ""
    throw new TemplateParseException(`模版不是合法 JSON：${message}`)
  }
  if (!isObject(root)) {
    throw new TemplateParseException("模版必须是 JSON 对象")
  }
  requireKeys(root, "$", new Set(["layout", "events"]), new Set(["layout"]))
  const events = parseEvents(root.events, "$.events")
  const ids = new Set<string>()
  const clicks: string[] = []
  const changes: string[] = []
  const budget = { left: MAX_NODES }
  const layout = parseNode(requireObject(root.layout, "$.layout"), "$.layout", ids, clicks, changes, budget, 0)
  for (const name of clicks) {
    if (!events[name]) {
      throw new TemplateParseException(`onClick 引用了不存在的事件 ${name}`)
    }
  }
  for (const name of changes) {
    if (!events[name]) {
      throw new TemplateParseException(`onChange 引用了不存在的事件 ${name}`)
    }
  }
  for (const [name, event] of Object.entries(events)) {
    const targets = eventTargets(event)
    for (const id of targets) {
      if (id && !ids.has(id)) {
        throw new TemplateParseException(`事件 ${name} 的 target「${id}」在模版中不存在`)
      }
    }
  }
  return { root: layout, events }
}

function eventTargets(event: EventSpec): string[] {
  if (event.kind === "setText" || event.kind === "setTextStyle") {
    return [event.target]
  }
  if (event.kind === "setChecked") {
    return event.targets
  }
  if (event.kind === "append") {
    return [event.list, event.from]
  }
  if (event.kind === "update" || event.kind === "remove") {
    return [event.list]
  }
  return []
}

function parseEvents(value: unknown, path: string): Record<string, EventSpec> {
  if (value == null) {
    return {}
  }
  const events = requireObject(value, path)
  const result: Record<string, EventSpec> = {}
  for (const [name, raw] of Object.entries(events)) {
    if (!namePattern.test(name)) {
      throw new TemplateParseException(`${path} 的事件名「${name}」必须是字母或下划线开头的标识符`)
    }
    result[name] = parseEvent(name, requireObject(raw, `${path}.${name}`), `${path}.${name}`)
  }
  return result
}

function parseEvent(name: string, event: JsonObject, path: string): EventSpec {
  const action = event.action
  if (typeof action !== "string") {
    throw new TemplateParseException(`${path} 缺少 action`)
  }
  if (action === "toast") {
    requireKeys(event, path, new Set(["action", "message"]), new Set(["action", "message"]))
    return { kind: "toast", message: requireString(event.message, `${path}.message`) }
  }
  if (action === "setText") {
    requireKeys(event, path, new Set(["action", "target", "value"]), new Set(["action", "target", "value"]))
    return {
      kind: "setText",
      target: requireName(event.target, `${path}.target`),
      value: requireString(event.value, `${path}.value`),
    }
  }
  if (action === "setTextStyle") {
    requireKeys(
      event,
      path,
      new Set(["action", "target", "fontSize", "color", "text"]),
      new Set(["action", "target"])
    )
    const style: { fontSize?: string; color?: string; text?: string } = {}
    if ("fontSize" in event) {
      style.fontSize = plainNumber(event.fontSize, `${path}.fontSize`)
    }
    if ("color" in event) {
      style.color = colorValue(event.color, `${path}.color`)
    }
    if ("text" in event) {
      style.text = requireString(event.text, `${path}.text`)
    }
    if (style.fontSize == null && style.color == null && style.text == null) {
      throw new TemplateParseException(`${path} 至少要写 fontSize、color、text 中的一个`)
    }
    return { kind: "setTextStyle", target: requireName(event.target, `${path}.target`), ...style }
  }
  if (action === "setChecked") {
    requireKeys(event, path, new Set(["action", "target", "value"]), new Set(["action", "target", "value"]))
    return {
      kind: "setChecked",
      targets: targetList(event.target, `${path}.target`),
      value: checkedValue(event.value, `${path}.value`),
    }
  }
  if (action === "append") {
    return parseAppend(event, path)
  }
  if (action === "update") {
    return parseUpdate(event, path)
  }
  if (action === "remove") {
    return parseRemove(event, path)
  }
  if (action === "open" || action === "replace" || action === "popTo") {
    return parsePage(event, path, action)
  }
  if (action === "host") {
    return parseHost(event, path)
  }
  if (action === "back") {
    requireKeys(event, path, new Set(["action", "params"]), new Set(["action"]))
    const spec: EventSpec = { kind: "back" }
    if ("params" in event) {
      spec.params = parseOpenParams(event.params, `${path}.params`)
    }
    return spec
  }
  throw new TemplateParseException(
    `${path}.action「${action}」无法识别，事件 ${name} 只能是 toast、setText、setTextStyle、setChecked、append、update、remove、open、back、replace、popTo、host`
  )
}

function parseOpenParams(value: unknown, path: string): JsonObject {
  const params = requireObject(value, path)
  const result: JsonObject = {}
  for (const [key, item] of Object.entries(params)) {
    if (!namePattern.test(key)) {
      throw new TemplateParseException(`${path}.${key} 不是这里能写的字段`)
    }
    result[key] = parseParamValue(item, `${path}.${key}`)
  }
  return result
}

function parseParamValue(value: unknown, path: string): Json {
  if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") {
    return value
  }
  if (Array.isArray(value)) {
    return value.map((item, index) => parseParamValue(item, `${path}[${index}]`))
  }
  if (isObject(value)) {
    return parseOpenParams(value, path)
  }
  throw new TemplateParseException(`${path} 必须是字符串、数字、布尔、对象或数组`)
}

function parsePage(event: JsonObject, path: string, kind: "open" | "replace" | "popTo"): EventSpec {
  requireKeys(event, path, new Set(["action", "page", "params"]), new Set(["action", "page"]))
  const page = requireString(event.page, `${path}.page`)
  if (!page.startsWith("$") && !namePattern.test(page)) {
    throw new TemplateParseException(`${path}.page 必须是页面名或以 $ 开头`)
  }
  const spec: EventSpec = { kind, page }
  if ("params" in event) {
    spec.params = parseOpenParams(event.params, `${path}.params`)
  }
  return spec
}

function parseHost(event: JsonObject, path: string): EventSpec {
  requireKeys(event, path, new Set(["action", "name", "params"]), new Set(["action", "name"]))
  const hostName = requireString(event.name, `${path}.name`)
  if (!hostName.startsWith("$") && !namePattern.test(hostName)) {
    throw new TemplateParseException(`${path}.name 必须是标识符或以 $ 开头`)
  }
  const spec: EventSpec = { kind: "host", name: hostName }
  if ("params" in event) {
    spec.params = parseOpenParams(event.params, `${path}.params`)
  }
  return spec
}

function parseAppend(event: JsonObject, path: string): EventSpec {
  requireKeys(
    event,
    path,
    new Set(["action", "list", "from", "field", "data", "item", "empty"]),
    new Set(["action", "list", "from", "field", "data", "item"])
  )
  const spec: EventSpec = {
    kind: "append",
    list: requireName(event.list, `${path}.list`),
    from: requireName(event.from, `${path}.from`),
    field: requireName(event.field, `${path}.field`),
    data: requireName(event.data, `${path}.data`),
    item: parseStringMap(event.item, `${path}.item`),
  }
  if ("empty" in event) {
    spec.empty = requireString(event.empty, `${path}.empty`)
  }
  return spec
}

function parseUpdate(event: JsonObject, path: string): EventSpec {
  requireKeys(event, path, new Set(["action", "list", "index", "item"]), new Set(["action", "list", "index", "item"]))
  return {
    kind: "update",
    list: requireName(event.list, `${path}.list`),
    index: indexValue(event.index, `${path}.index`),
    item: parseStringMap(event.item, `${path}.item`),
  }
}

function parseRemove(event: JsonObject, path: string): EventSpec {
  requireKeys(event, path, new Set(["action", "list", "index"]), new Set(["action", "list", "index"]))
  return {
    kind: "remove",
    list: requireName(event.list, `${path}.list`),
    index: indexValue(event.index, `${path}.index`),
  }
}

function parseStringMap(value: unknown, path: string): Record<string, string> {
  const item = requireObject(value, path)
  const fields: Record<string, string> = {}
  for (const [key, raw] of Object.entries(item)) {
    if (!namePattern.test(key)) {
      throw new TemplateParseException(`${path}.${key} 不是这里能写的字段`)
    }
    fields[key] = requireString(raw, `${path}.${key}`)
  }
  return fields
}

function indexValue(value: unknown, path: string): string {
  if (typeof value === "string") {
    if (value.startsWith("$")) {
      return value
    }
    throw new TemplateParseException(`${path} 必须是非负整数或以 $ 开头`)
  }
  if (typeof value === "number") {
    return nonNegativeInt(value, path)
  }
  throw new TemplateParseException(`${path} 必须是非负整数或以 $ 开头`)
}

function parseNode(
  node: JsonObject,
  path: string,
  ids: Set<string>,
  clicks: string[],
  changes: string[],
  budget: { left: number },
  depth: number
): ParsedNode {
  if (depth > MAX_DEPTH) {
    throw new TemplateParseException(`${path} 嵌套过深`)
  }
  if (budget.left <= 0) {
    throw new TemplateParseException(`${path} 节点过多`)
  }
  budget.left -= 1
  const type = node.type
  if (typeof type !== "string") {
    throw new TemplateParseException(`${path} 缺少 type`)
  }
  const viewName = viewNames[type]
  if (!viewName) {
    throw new TemplateParseException(`${path}.type「${type}」无法识别`)
  }
  const isContainer = type === "column" || type === "row"
  const allowed = new Set(["type", "id", "layout", "style", "onClick", "onChange", "visible"])
  const required = new Set(["type", "layout"])
  if (type === "column") {
    allowed.add("children")
    allowed.add("scroll")
  } else if (type === "row") {
    allowed.add("children")
  } else if (type === "text") {
    allowed.add("text")
    required.add("text")
  } else if (type === "image") {
    allowed.add("src")
    required.add("src")
  } else if (type === "list") {
    for (const key of ["data", "direction", "gap", "item"]) allowed.add(key)
    for (const key of ["id", "data", "item"]) required.add(key)
  } else if (type === "progress") {
    for (const key of ["from", "to", "animate"]) allowed.add(key)
  } else if (type === "lottie") {
    for (const key of ["src", "repeat", "mode", "autoPlay"]) allowed.add(key)
    required.add("src")
  } else if (type === "input") {
    for (const key of ["value", "hint", "keyboard", "maxLength", "lines"]) allowed.add(key)
  } else if (type === "checkbox" || type === "switch") {
    allowed.add("checked")
    allowed.add("label")
  } else if (type === "radio") {
    for (const key of ["checked", "label", "group"]) allowed.add(key)
    required.add("group")
  }
  requireKeys(node, path, allowed, required)

  const id = "id" in node ? requireName(node.id, `${path}.id`) : "0"
  if (id !== "0") {
    ids.add(id)
  }
  const attrs: Record<string, string> = {}
  if (id !== "0") {
    attrs.id = id
  }
  parseLayout(requireObject(node.layout, `${path}.layout`), `${path}.layout`, isContainer, attrs)
  if ("style" in node) {
    parseStyle(requireObject(node.style, `${path}.style`), `${path}.style`, type, attrs)
  }
  if ("visible" in node) {
    attrs.visible = checkedValue(node.visible, `${path}.visible`)
  }
  if ("onClick" in node) {
    const names = parseNames(node.onClick, `${path}.onClick`)
    if (names.length === 0) {
      throw new TemplateParseException(`${path}.onClick 不能是空数组`)
    }
    clicks.push(...names)
    attrs.onClick = names.join(",")
  }
  if ("onChange" in node) {
    const names = parseNames(node.onChange, `${path}.onChange`)
    if (names.length === 0) {
      throw new TemplateParseException(`${path}.onChange 不能是空数组`)
    }
    changes.push(...names)
    attrs.onChange = names.join(",")
  }
  if ("scroll" in node) {
    attrs.scroll = boolString(node.scroll, `${path}.scroll`)
  }
  if (type === "text") {
    attrs.text = requireString(node.text, `${path}.text`)
  } else if (type === "image") {
    attrs.src = requireString(node.src, `${path}.src`)
  } else if (type === "list") {
    parseListFields(node, path, attrs)
  } else if (type === "progress") {
    parseProgressFields(node, path, attrs)
  } else if (type === "lottie") {
    parseLottieFields(node, path, attrs)
  } else if (type === "input") {
    parseInputFields(node, path, attrs)
  } else if (type === "checkbox" || type === "switch") {
    parseCheckFields(node, path, attrs)
  } else if (type === "radio") {
    parseCheckFields(node, path, attrs)
    attrs.group = groupValue(node.group, `${path}.group`)
  }

  const children =
    isContainer && "children" in node
      ? requireArray(node.children, `${path}.children`).map((child, index) =>
          parseNode(
            requireObject(child, `${path}.children[${index}]`),
            `${path}.children[${index}]`,
            ids,
            clicks,
            changes,
            budget,
            depth + 1
          )
        )
      : []
  const item =
    type === "list"
      ? parseNode(requireObject(node.item, `${path}.item`), `${path}.item`, ids, clicks, changes, budget, depth + 1)
      : null
  return { viewName, id, attrs, children, item }
}

function parseLayout(layout: JsonObject, path: string, isContainer: boolean, attrs: Record<string, string>) {
  const allowed = new Set([
    "width",
    "height",
    "padding",
    "grow",
    "margin",
    "minWidth",
    "minHeight",
    "maxWidth",
    "maxHeight",
    "aspectRatio",
    "alignSelf",
  ])
  if (isContainer) {
    allowed.add("justify")
    allowed.add("align")
    allowed.add("wrap")
  }
  requireKeys(layout, path, allowed, new Set(["width", "height"]))
  attrs.width = sizeValue(layout.width, `${path}.width`)
  attrs.height = sizeValue(layout.height, `${path}.height`)
  if ("padding" in layout) {
    parseEdges(layout.padding, `${path}.padding`, "padding", "paddingStart", "paddingEnd", "paddingTop", "paddingBottom", attrs)
  }
  if ("margin" in layout) {
    parseEdges(layout.margin, `${path}.margin`, "margin", "marginStart", "marginEnd", "marginTop", "marginBottom", attrs)
  }
  putSize(layout, "minWidth", "minWidth", path, attrs)
  putSize(layout, "minHeight", "minHeight", path, attrs)
  putSize(layout, "maxWidth", "maxWidth", path, attrs)
  putSize(layout, "maxHeight", "maxHeight", path, attrs)
  if ("aspectRatio" in layout) {
    attrs.aspectRatio = positiveNumber(layout.aspectRatio, `${path}.aspectRatio`)
  }
  if ("alignSelf" in layout) {
    const alignSelf = requireString(layout.alignSelf, `${path}.alignSelf`)
    if (!alignSelfValues.has(alignSelf)) {
      throw new TemplateParseException(`${path}.alignSelf 只能是 start、center、end、stretch`)
    }
    attrs.alignSelf = alignSelf
  }
  if ("grow" in layout) {
    attrs.flexGrow = plainNumber(layout.grow, `${path}.grow`)
  }
  if ("wrap" in layout) {
    attrs.flexWrap = boolString(layout.wrap, `${path}.wrap`) === "true" ? "wrap" : "nowrap"
  }
  if ("justify" in layout) {
    attrs.justifyContent = flexValue(layout.justify, `${path}.justify`, justifyValues)
  }
  if ("align" in layout) {
    attrs.alignItems = enumValue(layout.align, `${path}.align`, alignValues)
  }
}

function putSize(layout: JsonObject, key: string, attrName: string, path: string, attrs: Record<string, string>) {
  if (key in layout) {
    attrs[attrName] = sizeValue(layout[key], `${path}.${key}`)
  }
}

function parseEdges(
  value: unknown,
  path: string,
  uniform: string,
  start: string,
  end: string,
  top: string,
  bottom: string,
  attrs: Record<string, string>
) {
  if (typeof value === "number") {
    attrs[uniform] = plainNumber(value, path)
    return
  }
  if (isObject(value)) {
    requireKeys(value, path, new Set(["start", "end", "top", "bottom"]), new Set())
    if (Object.keys(value).length === 0) {
      throw new TemplateParseException(`${path} 不能是空对象`)
    }
    putSide(value, "start", start, path, attrs)
    putSide(value, "end", end, path, attrs)
    putSide(value, "top", top, path, attrs)
    putSide(value, "bottom", bottom, path, attrs)
    return
  }
  throw new TemplateParseException(`${path} 必须是数字或四边对象`)
}

function putSide(source: JsonObject, key: string, attrName: string, path: string, attrs: Record<string, string>) {
  if (key in source) {
    attrs[attrName] = plainNumber(source[key], `${path}.${key}`)
  }
}

function parseStyle(style: JsonObject, path: string, type: string, attrs: Record<string, string>) {
  const allowed = new Set(["background", "radius", "border"])
  if (type === "column" || type === "row" || type === "spacer") {
    allowed.add("glass")
  }
  if (type === "text") {
    for (const key of ["color", "fontSize", "align", "maxLines", "ellipsis", "fontWeight"]) allowed.add(key)
  } else if (type === "image") {
    allowed.add("fit")
    allowed.add("placeholder")
  } else if (type === "input") {
    for (const key of ["color", "fontSize", "align", "hintColor", "lines"]) allowed.add(key)
  } else if (type === "checkbox" || type === "radio" || type === "switch") {
    for (const key of ["color", "fontSize", "tint"]) allowed.add(key)
  } else if (type === "progress") {
    allowed.add("track")
    allowed.add("bar")
  }
  requireKeys(style, path, allowed, new Set())
  if (Object.keys(style).length === 0) {
    throw new TemplateParseException(`${path} 不能是空对象`)
  }
  if ("background" in style && "glass" in style) {
    throw new TemplateParseException(`${path} 不能同时写 background 和 glass`)
  }
  if ("background" in style) {
    attrs.background = backgroundValue(style.background, `${path}.background`)
  }
  if ("radius" in style) {
    parseRadius(style.radius, `${path}.radius`, attrs)
  }
  if ("border" in style) {
    parseBorder(requireObject(style.border, `${path}.border`), `${path}.border`, attrs)
  }
  if ("glass" in style) {
    parseGlass(requireObject(style.glass, `${path}.glass`), `${path}.glass`, attrs)
  }
  if ("color" in style) {
    attrs.textColor = colorValue(style.color, `${path}.color`)
  }
  if ("fontSize" in style) {
    attrs.textSize = plainNumber(style.fontSize, `${path}.fontSize`)
  }
  if ("align" in style) {
    const align = requireString(style.align, `${path}.align`)
    if (!textAlignValues.has(align)) {
      throw new TemplateParseException(`${path}.align 只能是 start、center、end`)
    }
    attrs.textAlign = align
  }
  if ("hintColor" in style) {
    attrs.hintColor = colorValue(style.hintColor, `${path}.hintColor`)
  }
  if ("tint" in style) {
    attrs.tint = colorValue(style.tint, `${path}.tint`)
  }
  if ("track" in style) {
    attrs.strokeColor = paintValue(style.track, `${path}.track`)
  }
  if ("bar" in style) {
    attrs.trailColor = paintValue(style.bar, `${path}.bar`)
  }
  if ("maxLines" in style) {
    attrs.maxLines = positiveInt(style.maxLines, `${path}.maxLines`)
  }
  if ("ellipsis" in style) {
    attrs.ellipsis = boolString(style.ellipsis, `${path}.ellipsis`)
  }
  if ("fontWeight" in style) {
    const weight = requireString(style.fontWeight, `${path}.fontWeight`)
    if (!fontWeights.has(weight)) {
      throw new TemplateParseException(`${path}.fontWeight 只能是 regular、medium、bold`)
    }
    attrs.fontWeight = weight
  }
  if ("fit" in style) {
    const fit = requireString(style.fit, `${path}.fit`)
    if (!imageFits.has(fit)) {
      throw new TemplateParseException(`${path}.fit 只能是 cover、contain、fill`)
    }
    attrs.fit = fit
  }
  if ("placeholder" in style) {
    attrs.placeholder = solidColor(style.placeholder, `${path}.placeholder`)
  }
  if ("lines" in style) {
    attrs.lines = positiveInt(style.lines, `${path}.lines`)
  }
}

function parseRadius(value: unknown, path: string, attrs: Record<string, string>) {
  if (typeof value === "number") {
    attrs.radius = plainNumber(value, path)
    return
  }
  if (isObject(value)) {
    requireKeys(value, path, new Set(["topStart", "topEnd", "bottomEnd", "bottomStart"]), new Set())
    if (Object.keys(value).length === 0) {
      throw new TemplateParseException(`${path} 不能是空对象`)
    }
    putSide(value, "topStart", "leftTopRadius", path, attrs)
    putSide(value, "topEnd", "rightTopRadius", path, attrs)
    putSide(value, "bottomEnd", "rightBottomRadius", path, attrs)
    putSide(value, "bottomStart", "leftBottomRadius", path, attrs)
    return
  }
  throw new TemplateParseException(`${path} 必须是数字或四角对象`)
}

function parseGlass(glass: JsonObject, path: string, attrs: Record<string, string>) {
  requireKeys(glass, path, new Set(["style", "tint", "interactive"]), new Set())
  const style = "style" in glass ? requireString(glass.style, `${path}.style`) : "regular"
  if (style !== "regular" && style !== "clear") {
    throw new TemplateParseException(`${path}.style 只能是 regular、clear`)
  }
  attrs.glassStyle = style
  if ("tint" in glass) {
    attrs.glassTint = solidColor(glass.tint, `${path}.tint`)
  }
  if ("interactive" in glass) {
    attrs.glassInteractive = boolString(glass.interactive, `${path}.interactive`)
  }
}

function parseBorder(border: JsonObject, path: string, attrs: Record<string, string>) {
  requireKeys(border, path, new Set(["color", "width"]), new Set(["color", "width"]))
  attrs.borderColor = colorValue(border.color, `${path}.color`)
  attrs.borderWidth = plainNumber(border.width, `${path}.width`)
}

function parseListFields(node: JsonObject, path: string, attrs: Record<string, string>) {
  const data = requireString(node.data, `${path}.data`)
  if (!data.startsWith("$")) {
    throw new TemplateParseException(`${path}.data 必须是 $ 开头的表达式`)
  }
  attrs.data = data
  const direction = "direction" in node ? requireString(node.direction, `${path}.direction`) : "vertical"
  if (direction !== "horizontal" && direction !== "vertical") {
    throw new TemplateParseException(`${path}.direction 只能是 horizontal 或 vertical`)
  }
  attrs.listDirection = direction
  if ("gap" in node) {
    attrs.itemPadding = plainNumber(node.gap, `${path}.gap`)
  }
}

function parseProgressFields(node: JsonObject, path: string, attrs: Record<string, string>) {
  if ("from" in node) {
    attrs.valueMin = fractionValue(node.from, `${path}.from`)
  }
  if ("to" in node) {
    attrs.valueMax = fractionValue(node.to, `${path}.to`)
  }
  if ("animate" in node) {
    attrs.animateEnable = boolString(node.animate, `${path}.animate`)
  }
}

function parseInputFields(node: JsonObject, path: string, attrs: Record<string, string>) {
  if ("value" in node) {
    attrs.text = requireString(node.value, `${path}.value`)
  }
  if ("hint" in node) {
    attrs.hint = requireString(node.hint, `${path}.hint`)
  }
  const keyboard = "keyboard" in node ? requireString(node.keyboard, `${path}.keyboard`) : "text"
  if (!keyboardValues.has(keyboard)) {
    throw new TemplateParseException(`${path}.keyboard 只能是 text、number、password、email、phone`)
  }
  attrs.inputType = keyboard
  if ("maxLength" in node) {
    attrs.maxLength = nonNegativeInt(node.maxLength, `${path}.maxLength`)
  }
  if ("lines" in node) {
    attrs.lines = positiveInt(node.lines, `${path}.lines`)
  }
}

function parseCheckFields(node: JsonObject, path: string, attrs: Record<string, string>) {
  attrs.checked = "checked" in node ? checkedValue(node.checked, `${path}.checked`) : "false"
  if ("label" in node) {
    attrs.text = requireString(node.label, `${path}.label`)
  }
}

function parseLottieFields(node: JsonObject, path: string, attrs: Record<string, string>) {
  attrs.animationSrc = requireString(node.src, `${path}.src`)
  attrs.repeatCount = "repeat" in node ? repeatValue(node.repeat, `${path}.repeat`) : "infinite"
  if ("mode" in node) {
    const mode = requireString(node.mode, `${path}.mode`)
    if (mode !== "restart" && mode !== "reverse") {
      throw new TemplateParseException(`${path}.mode 只能是 restart 或 reverse`)
    }
    attrs.repeatMode = mode
  } else {
    attrs.repeatMode = "restart"
  }
  attrs.autoPlay = "autoPlay" in node ? boolString(node.autoPlay, `${path}.autoPlay`) : "true"
}

function parseNames(value: unknown, path: string): string[] {
  return requireArray(value, path).map((item, index) => requireName(item, `${path}[${index}]`))
}

function sizeValue(value: unknown, path: string): string {
  if (typeof value === "number") {
    return plainNumber(value, path)
  }
  if (value === "fill") {
    return "match_parent"
  }
  if (value === "wrap") {
    return "wrap_content"
  }
  throw new TemplateParseException(`${path} 只能是数字、fill 或 wrap`)
}

function backgroundValue(value: unknown, path: string): string {
  if (typeof value === "string") {
    if (value.startsWith("res:")) {
      const name = value.slice(4)
      if (!namePattern.test(name)) {
        throw new TemplateParseException(`${path} 的资源名必须是字母或下划线开头`)
      }
      return value
    }
    return colorValue(value, path)
  }
  if (isObject(value)) {
    requireKeys(value, path, new Set(["direction", "colors"]), new Set(["direction", "colors"]))
    const direction = enumValue(value.direction, `${path}.direction`, gradientDirections)
    const colors = requireArray(value.colors, `${path}.colors`)
    if (colors.length < 2) {
      throw new TemplateParseException(`${path}.colors 至少要有两个颜色`)
    }
    const colorList = colors.map((color, index) => colorValue(color, `${path}.colors[${index}]`))
    return `linear-gradient(${direction}, ${colorList.join(", ")})`
  }
  throw new TemplateParseException(`${path} 必须是颜色或渐变对象`)
}

function paintValue(value: unknown, path: string): string {
  if (isObject(value)) {
    return backgroundValue(value, path)
  }
  return colorValue(value, path)
}

function colorValue(value: unknown, path: string): string {
  const color = requireString(value, path)
  if (color === "transparent" || color.startsWith("$") || colorPattern.test(color)) {
    return color
  }
  throw new TemplateParseException(`${path} 必须是 #RGB、#RRGGBB、#AARRGGBB、transparent，或以 $ 开头`)
}

function fractionValue(value: unknown, path: string): string {
  if (typeof value === "number") {
    return plainNumber(value, path)
  }
  if (typeof value === "string") {
    if (value.startsWith("$") || Number.isFinite(Number(value))) {
      return value
    }
  }
  throw new TemplateParseException(`${path} 必须是数字或以 $ 开头`)
}

function repeatValue(value: unknown, path: string): string {
  if (value === "infinite") {
    return value
  }
  if (typeof value === "number") {
    const number = plainNumber(value, path)
    if (number.includes(".")) {
      throw new TemplateParseException(`${path} 只能是 infinite 或非负整数`)
    }
    return number
  }
  throw new TemplateParseException(`${path} 只能是 infinite 或非负整数`)
}

function enumValue(value: unknown, path: string, mapping: Record<string, string>): string {
  const name = requireString(value, path)
  const mapped = mapping[name]
  if (!mapped) {
    throw new TemplateParseException(`${path}「${name}」不在允许的取值里`)
  }
  return mapped
}

function flexValue(value: unknown, path: string, mapping: Record<string, string>): string {
  const name = requireString(value, path)
  if (name.startsWith("$")) {
    return name
  }
  return enumValue(value, path, mapping)
}

function targetList(value: unknown, path: string): string[] {
  const names = Array.isArray(value)
    ? value.map((item, index) => requireName(item, `${path}[${index}]`))
    : [requireName(value, path)]
  if (names.length === 0) {
    throw new TemplateParseException(`${path} 不能是空数组`)
  }
  return names
}

function plainNumber(value: unknown, path: string): string {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new TemplateParseException(`${path} 必须是数字`)
  }
  if (value < 0) {
    throw new TemplateParseException(`${path} 不能是负数`)
  }
  return stripNumber(value)
}

function stripNumber(value: number): string {
  const text = Object.is(value, -0) ? "0" : String(value)
  if (!/[eE]/.test(text)) {
    return text
  }
  return value.toFixed(12).replace(/\.?0+$/, "")
}

function boolString(value: unknown, path: string): string {
  if (typeof value !== "boolean") {
    throw new TemplateParseException(`${path} 必须是布尔值`)
  }
  return value ? "true" : "false"
}

function groupValue(value: unknown, path: string): string {
  const name = requireString(value, path)
  if (name.startsWith("$") || namePattern.test(name)) {
    return name
  }
  throw new TemplateParseException(`${path}「${name}」必须是字母或下划线开头的标识符，或以 $ 开头`)
}

function checkedValue(value: unknown, path: string): string {
  if (typeof value === "boolean") {
    return value ? "true" : "false"
  }
  if (typeof value === "string" && value.startsWith("$")) {
    return value
  }
  throw new TemplateParseException(`${path} 必须是布尔值或以 $ 开头`)
}

function positiveNumber(value: unknown, path: string): string {
  const number = plainNumber(value, path)
  if (number === "0") {
    throw new TemplateParseException(`${path} 必须是正数`)
  }
  return number
}

function positiveInt(value: unknown, path: string): string {
  const number = nonNegativeInt(value, path)
  if (number === "0") {
    throw new TemplateParseException(`${path} 必须是正整数`)
  }
  return number
}

function solidColor(value: unknown, path: string): string {
  if (isObject(value)) {
    throw new TemplateParseException(`${path} 必须是颜色，不能是渐变`)
  }
  return colorValue(value, path)
}

function nonNegativeInt(value: unknown, path: string): string {
  const number = plainNumber(value, path)
  if (number.includes(".")) {
    throw new TemplateParseException(`${path} 只能是非负整数`)
  }
  return number
}

function requireObject(value: unknown, path: string): JsonObject {
  if (!isObject(value)) {
    throw new TemplateParseException(`${path} 必须是对象`)
  }
  return value
}

function requireArray(value: unknown, path: string): unknown[] {
  if (!Array.isArray(value)) {
    throw new TemplateParseException(`${path} 必须是数组`)
  }
  return value
}

function requireString(value: unknown, path: string): string {
  if (typeof value !== "string") {
    throw new TemplateParseException(`${path} 必须是字符串`)
  }
  return value
}

function requireName(value: unknown, path: string): string {
  const name = requireString(value, path)
  if (!namePattern.test(name)) {
    throw new TemplateParseException(`${path}「${name}」必须是字母或下划线开头的标识符`)
  }
  return name
}

function requireKeys(node: JsonObject, path: string, allowed: Set<string>, required: Set<string>) {
  for (const key of Object.keys(node)) {
    if (!allowed.has(key)) {
      throw new TemplateParseException(`${path}.${key} 不是这里能写的字段`)
    }
  }
  for (const key of required) {
    if (!(key in node)) {
      throw new TemplateParseException(`${path} 缺少 ${key}`)
    }
  }
}

function isObject(value: unknown): value is JsonObject {
  return value != null && typeof value === "object" && !Array.isArray(value)
}
