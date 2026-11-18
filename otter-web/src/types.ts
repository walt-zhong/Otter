export type Json = null | boolean | number | string | Json[] | JsonObject

export type JsonObject = { [key: string]: Json }

export type ViewPort = {
  width: number
  height: number
}

export class TemplateParseException extends Error {
  constructor(message: string) {
    super(message)
    this.name = "TemplateParseException"
  }
}

export type ParsedNode = {
  viewName: string
  id: string
  attrs: Record<string, string>
  children: ParsedNode[]
  item: ParsedNode | null
}

export type EventSpec =
  | { kind: "toast"; message: string }
  | { kind: "setText"; target: string; value: string }
  | {
      kind: "setTextStyle"
      target: string
      fontSize?: string
      color?: string
      text?: string
    }
  | { kind: "setChecked"; targets: string[]; value: string }
  | {
      kind: "append"
      list: string
      from: string
      field: string
      data: string
      item: Record<string, string>
      empty?: string
    }
  | { kind: "update"; list: string; index: string; item: Record<string, string> }
  | { kind: "remove"; list: string; index: string }
  | { kind: "open" | "replace" | "popTo"; page: string; params?: JsonObject }
  | { kind: "back"; params?: JsonObject }
  | { kind: "host"; name: string; params?: JsonObject }

export type ParsedTemplate = {
  root: ParsedNode
  events: Record<string, EventSpec>
}
