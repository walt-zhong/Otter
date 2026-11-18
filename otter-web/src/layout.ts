import Yoga, {
  Align,
  Direction,
  Display,
  Edge,
  FlexDirection,
  Justify,
  MeasureMode,
  Wrap,
  type Node as YogaNode,
} from "yoga-layout"
import { measureText, type TextMeasure } from "./measure"
import type { ViewPort } from "./types"

export type LayoutNode = {
  width: string
  height: string
  minWidth?: string
  minHeight?: string
  maxWidth?: string
  maxHeight?: string
  padding: Edges
  margin: Edges
  grow: number
  aspectRatio?: number
  alignSelf?: string
  justify?: string
  align?: string
  wrap: boolean
  hidden: boolean
  scroll: boolean
  mirror: boolean
  direction: "column" | "row" | "leaf"
  text?: TextMeasure
  children: LayoutNode[]
}

export type Edges = { start: number; end: number; top: number; bottom: number }

export type LayoutBox = {
  x: number
  y: number
  width: number
  height: number
  scroll: boolean
  mirror: boolean
  contentWidth: number
  contentHeight: number
  children: LayoutBox[]
}

export function emptyEdges(): Edges {
  return { start: 0, end: 0, top: 0, bottom: 0 }
}

export function layoutTree(root: LayoutNode, viewport: ViewPort, density: number): LayoutBox {
  const view = Yoga.Node.create()
  view.setWidth(viewport.width)
  view.setHeight(viewport.height)
  view.setFlexDirection(FlexDirection.Column)
  const child = buildNode(root, density)
  view.insertChild(child, 0)
  view.calculateLayout(viewport.width, viewport.height, Direction.LTR)
  const box = readBox(child)
  annotate(box, root)
  view.freeRecursive()
  return box
}

export function layoutItem(
  node: LayoutNode,
  constraint: { width?: number; height?: number },
  density: number
): LayoutBox {
  const view = Yoga.Node.create()
  if (constraint.width != null) {
    view.setWidth(constraint.width)
  } else {
    view.setWidthAuto()
  }
  if (constraint.height != null) {
    view.setHeight(constraint.height)
  } else {
    view.setHeightAuto()
  }
  const child = buildNode(node, density)
  view.insertChild(child, 0)
  view.calculateLayout(constraint.width, constraint.height, Direction.LTR)
  const box = readBox(child)
  annotate(box, node)
  view.freeRecursive()
  return box
}

function annotate(box: LayoutBox, node: LayoutNode) {
  box.scroll = node.scroll
  box.mirror = node.mirror
  if (node.mirror) {
    for (const child of box.children) {
      child.x = Math.max(0, box.width - child.x - child.width)
    }
  }
  node.children.forEach((child, index) => {
    const next = box.children[index]
    if (next) {
      annotate(next, child)
    }
  })
}

function buildNode(node: LayoutNode, density: number): YogaNode {
  const yoga = Yoga.Node.create()
  if (node.hidden) {
    yoga.setDisplay(Display.None)
  }
  if (node.direction === "column") {
    yoga.setFlexDirection(FlexDirection.Column)
  } else if (node.direction === "row") {
    yoga.setFlexDirection(FlexDirection.Row)
  }
  applySize(yoga, "width", node.width, density)
  applySize(yoga, "height", node.height, density)
  if (node.minWidth) applyBound(yoga, "minWidth", node.minWidth, density)
  if (node.minHeight) applyBound(yoga, "minHeight", node.minHeight, density)
  if (node.maxWidth) applyBound(yoga, "maxWidth", node.maxWidth, density)
  if (node.maxHeight) applyBound(yoga, "maxHeight", node.maxHeight, density)
  if (node.grow > 0) {
    yoga.setFlexGrow(node.grow)
  }
  if (node.aspectRatio != null) {
    yoga.setAspectRatio(node.aspectRatio)
  }
  if (node.alignSelf) {
    yoga.setAlignSelf(alignOf(node.alignSelf))
  }
  if (node.justify && !node.justify.startsWith("$")) {
    yoga.setJustifyContent(justifyOf(node.justify))
  }
  if (node.align) {
    yoga.setAlignItems(alignOf(node.align))
  }
  yoga.setFlexWrap(node.wrap ? Wrap.Wrap : Wrap.NoWrap)
  yoga.setPadding(Edge.Left, node.padding.start * density)
  yoga.setPadding(Edge.Right, node.padding.end * density)
  yoga.setPadding(Edge.Top, node.padding.top * density)
  yoga.setPadding(Edge.Bottom, node.padding.bottom * density)
  yoga.setMargin(Edge.Left, node.margin.start * density)
  yoga.setMargin(Edge.Right, node.margin.end * density)
  yoga.setMargin(Edge.Top, node.margin.top * density)
  yoga.setMargin(Edge.Bottom, node.margin.bottom * density)
  if (node.text && (node.width === "wrap_content" || node.height === "wrap_content")) {
    const spec = node.text
    yoga.setMeasureFunc((width, widthMode, height, heightMode) => {
      const limit =
        widthMode === MeasureMode.Undefined ? Number.POSITIVE_INFINITY : Math.max(0, width)
      const measured = measureText(spec, limit)
      return {
        width: widthMode === MeasureMode.Exactly ? width : Math.min(measured.width, limit),
        height: heightMode === MeasureMode.Exactly ? height : measured.height,
      }
    })
  }
  node.children.forEach((child, index) => {
    yoga.insertChild(buildNode(child, density), index)
  })
  return yoga
}

function applySize(node: YogaNode, axis: "width" | "height", value: string, density: number) {
  const setAuto = axis === "width" ? node.setWidthAuto.bind(node) : node.setHeightAuto.bind(node)
  const setPercent = axis === "width" ? node.setWidthPercent.bind(node) : node.setHeightPercent.bind(node)
  const set = axis === "width" ? node.setWidth.bind(node) : node.setHeight.bind(node)
  if (value === "wrap_content") {
    setAuto()
    return
  }
  if (value === "match_parent") {
    setPercent(100)
    return
  }
  set(Number(value) * density)
}

function applyBound(
  node: YogaNode,
  bound: "minWidth" | "minHeight" | "maxWidth" | "maxHeight",
  value: string,
  density: number
) {
  const percent = {
    minWidth: node.setMinWidthPercent.bind(node),
    minHeight: node.setMinHeightPercent.bind(node),
    maxWidth: node.setMaxWidthPercent.bind(node),
    maxHeight: node.setMaxHeightPercent.bind(node),
  }[bound]
  const exact = {
    minWidth: node.setMinWidth.bind(node),
    minHeight: node.setMinHeight.bind(node),
    maxWidth: node.setMaxWidth.bind(node),
    maxHeight: node.setMaxHeight.bind(node),
  }[bound]
  if (value === "match_parent") {
    percent(100)
    return
  }
  if (value === "wrap_content") {
    return
  }
  exact(Number(value) * density)
}

function justifyOf(value: string): Justify {
  switch (value) {
    case "center":
      return Justify.Center
    case "end":
      return Justify.FlexEnd
    case "space-between":
      return Justify.SpaceBetween
    case "space-around":
      return Justify.SpaceAround
    case "space-evenly":
      return Justify.SpaceEvenly
    default:
      return Justify.FlexStart
  }
}

function alignOf(value: string): Align {
  switch (value) {
    case "center":
      return Align.Center
    case "end":
      return Align.FlexEnd
    case "baseline":
      return Align.Baseline
    case "stretch":
      return Align.Stretch
    default:
      return Align.FlexStart
  }
}

function readBox(node: YogaNode): LayoutBox {
  const width = node.getComputedWidth()
  const height = node.getComputedHeight()
  const children: LayoutBox[] = []
  for (let index = 0; index < node.getChildCount(); index += 1) {
    const child = node.getChild(index)
    const box = readBox(child)
    box.x = child.getComputedLeft()
    box.y = child.getComputedTop()
    children.push(box)
  }
  let contentWidth = width
  let contentHeight = height
  for (const child of children) {
    contentWidth = Math.max(contentWidth, child.x + child.width)
    contentHeight = Math.max(contentHeight, child.y + child.height)
  }
  return {
    x: 0,
    y: 0,
    width,
    height,
    scroll: false,
    mirror: false,
    contentWidth,
    contentHeight,
    children,
  }
}
