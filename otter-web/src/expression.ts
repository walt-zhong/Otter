import type { Json, JsonObject } from "./types"

type Data = JsonObject | Json[] | null | undefined

const ident = /[A-Za-z_][A-Za-z0-9_]*/

type Token =
  | { t: "num"; v: number }
  | { t: "str"; v: string }
  | { t: "bool"; v: boolean }
  | { t: "null" }
  | { t: "value"; v: string }
  | { t: "data" }
  | { t: "id"; v: string }
  | { t: "op"; v: string }

export function getResult(expression: unknown, data: Data): unknown {
  if (typeof expression !== "string") {
    return expression ?? null
  }
  if (expression.trim() === "") {
    return null
  }
  if (expression.trim() === "$$") {
    return data ?? null
  }
  try {
    const tokens = tokenize(expression)
    const parser = new Parser(tokens, data)
    const value = parser.parseExpression()
    if (!parser.done()) {
      return null
    }
    return value
  } catch {
    return null
  }
}

export function displayValue(expression: string, data: Data): string {
  const value = getResult(expression, data)
  if (value == null) {
    return expression
  }
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      return expression
    }
    return formatNumber(value)
  }
  if (typeof value === "boolean") {
    return value ? "true" : "false"
  }
  if (typeof value === "string") {
    return value
  }
  return expression
}

export function isExpression(value: string): boolean {
  return value.startsWith("$")
}

function formatNumber(value: number): string {
  if (Number.isInteger(value)) {
    return String(value)
  }
  return String(value)
}

function tokenize(source: string): Token[] {
  const tokens: Token[] = []
  let i = 0
  while (i < source.length) {
    const ch = source[i]
    if (ch === " " || ch === "\n" || ch === "\t" || ch === "\r") {
      i += 1
      continue
    }
    if (ch === "$") {
      if (source[i + 1] === "$") {
        tokens.push({ t: "data" })
        i += 2
        continue
      }
      i += 1
      const start = i
      while (i < source.length && /[A-Za-z0-9_.[\]]/.test(source[i])) {
        i += 1
      }
      tokens.push({ t: "value", v: source.slice(start, i) })
      continue
    }
    if (ch === "'") {
      i += 1
      const start = i
      while (i < source.length && source[i] !== "'") {
        i += 1
      }
      if (i >= source.length) {
        throw new Error("string")
      }
      tokens.push({ t: "str", v: source.slice(start, i) })
      i += 1
      continue
    }
    if (/[0-9]/.test(ch)) {
      const start = i
      let dot = false
      while (i < source.length && /[0-9.]/.test(source[i])) {
        if (source[i] === ".") {
          if (dot) {
            throw new Error("num")
          }
          dot = true
        }
        i += 1
      }
      if (/[A-Za-z_]/.test(source[i] ?? "")) {
        throw new Error("num")
      }
      tokens.push({ t: "num", v: Number(source.slice(start, i)) })
      continue
    }
    if (/[A-Za-z_]/.test(ch)) {
      const start = i
      while (i < source.length && /[A-Za-z0-9_]/.test(source[i])) {
        i += 1
      }
      const word = source.slice(start, i)
      if (word === "true") {
        tokens.push({ t: "bool", v: true })
      } else if (word === "false") {
        tokens.push({ t: "bool", v: false })
      } else if (word === "null") {
        tokens.push({ t: "null" })
      } else if (!ident.test(word)) {
        throw new Error("id")
      } else {
        tokens.push({ t: "id", v: word })
      }
      continue
    }
    const two = source.slice(i, i + 2)
    if ([">=", "<=", "==", "!=", "&&", "||", "?:"].includes(two)) {
      tokens.push({ t: "op", v: two })
      i += 2
      continue
    }
    if ("+-*/%><!?:(),".includes(ch)) {
      tokens.push({ t: "op", v: ch })
      i += 1
      continue
    }
    throw new Error("token")
  }
  return tokens
}

class Parser {
  private index = 0

  constructor(
    private readonly tokens: Token[],
    private readonly data: Data
  ) {}

  done(): boolean {
    return this.index >= this.tokens.length
  }

  parseExpression(): unknown {
    return this.parseTernary()
  }

  private parseTernary(): unknown {
    const condition = this.parseOr()
    if (this.matchOp("?:")) {
      const fallback = this.parseOr()
      return truthy(condition) ? condition : fallback
    }
    if (this.matchOp("?")) {
      const yes = this.parseOr()
      this.expectOp(":")
      const no = this.parseTernary()
      return truthy(condition) ? yes : no
    }
    return condition
  }

  private parseOr(): unknown {
    let left = this.parseAnd()
    while (this.matchOp("||")) {
      const right = this.parseAnd()
      left = truthy(left) ? left : right
    }
    return left
  }

  private parseAnd(): unknown {
    let left = this.parseEquality()
    while (this.matchOp("&&")) {
      const right = this.parseEquality()
      left = truthy(left) && truthy(right) ? right : false
    }
    return left
  }

  private parseEquality(): unknown {
    let left = this.parseCompare()
    while (true) {
      if (this.matchOp("==")) {
        const right = this.parseCompare()
        left = same(left, right)
      } else if (this.matchOp("!=")) {
        const right = this.parseCompare()
        left = !same(left, right)
      } else {
        return left
      }
    }
  }

  private parseCompare(): unknown {
    let left = this.parseAdd()
    while (true) {
      const op = this.peekOp()
      if (op !== ">" && op !== "<" && op !== ">=" && op !== "<=") {
        return left
      }
      this.index += 1
      const right = this.parseAdd()
      const a = num(left)
      const b = num(right)
      if (a == null || b == null) {
        left = false
        continue
      }
      if (op === ">") left = a > b
      else if (op === "<") left = a < b
      else if (op === ">=") left = a >= b
      else left = a <= b
    }
  }

  private parseAdd(): unknown {
    let left = this.parseMul()
    while (true) {
      if (this.matchOp("+")) {
        left = add(left, this.parseMul())
      } else if (this.matchOp("-")) {
        left = sub(left, this.parseMul())
      } else {
        return left
      }
    }
  }

  private parseMul(): unknown {
    let left = this.parseUnary()
    while (true) {
      if (this.matchOp("*")) {
        left = mul(left, this.parseUnary())
      } else if (this.matchOp("/")) {
        left = div(left, this.parseUnary())
      } else if (this.matchOp("%")) {
        left = mod(left, this.parseUnary())
      } else {
        return left
      }
    }
  }

  private parseUnary(): unknown {
    if (this.matchOp("!")) {
      return !truthy(this.parseUnary())
    }
    if (this.matchOp("+")) {
      const value = num(this.parseUnary())
      if (value == null) {
        throw new Error("unary")
      }
      return value
    }
    if (this.matchOp("-")) {
      const value = num(this.parseUnary())
      if (value == null) {
        throw new Error("unary")
      }
      return -value
    }
    return this.parsePrimary()
  }

  private parsePrimary(): unknown {
    const token = this.tokens[this.index]
    if (!token) {
      throw new Error("eof")
    }
    if (token.t === "op" && token.v === "(") {
      this.index += 1
      const value = this.parseExpression()
      this.expectOp(")")
      return value
    }
    if (token.t === "id") {
      this.index += 1
      this.expectOp("(")
      const args: unknown[] = []
      if (!this.peekOpIs(")")) {
        args.push(this.parseExpression())
        while (this.matchOp(",")) {
          args.push(this.parseExpression())
        }
      }
      this.expectOp(")")
      return callFunction(token.v, args)
    }
    this.index += 1
    if (token.t === "num" || token.t === "str" || token.t === "bool") {
      return token.v
    }
    if (token.t === "null") {
      return null
    }
    if (token.t === "data") {
      return this.data ?? null
    }
    if (token.t === "value") {
      return readPath(this.data, token.v)
    }
    throw new Error("primary")
  }

  private matchOp(op: string): boolean {
    const token = this.tokens[this.index]
    if (token && token.t === "op" && token.v === op) {
      this.index += 1
      return true
    }
    return false
  }

  private expectOp(op: string) {
    if (!this.matchOp(op)) {
      throw new Error(op)
    }
  }

  private peekOp(): string | null {
    const token = this.tokens[this.index]
    if (token && token.t === "op") {
      return token.v
    }
    return null
  }

  private peekOpIs(op: string): boolean {
    return this.peekOp() === op
  }
}

function callFunction(name: string, args: unknown[]): unknown {
  if (name === "size" && args.length === 1) {
    const value = args[0]
    if (typeof value === "string") {
      return value.length
    }
    if (Array.isArray(value)) {
      return value.length
    }
    if (value && typeof value === "object") {
      return Object.keys(value).length
    }
    return 0
  }
  if (name === "env" && args.length === 1 && typeof args[0] === "string") {
    const key = args[0].toLowerCase()
    if (key === "isandroid" || key === "isios") {
      return false
    }
    if (key === "isweb") {
      return true
    }
    throw new Error("env")
  }
  throw new Error("fn")
}

function readPath(source: Data, path: string): unknown {
  if (!path) {
    return null
  }
  if (!source || typeof source !== "object" || Array.isArray(source)) {
    return null
  }
  return readFrom(source, path)
}

function readFrom(source: Json, path: string): unknown {
  if (path === "") {
    return source
  }
  const bracket = path.indexOf("[")
  const dot = path.indexOf(".")
  if (bracket !== -1 && (dot === -1 || bracket < dot)) {
    const name = path.slice(0, bracket)
    const end = path.indexOf("]", bracket)
    if (end === -1) {
      return null
    }
    const index = Number(path.slice(bracket + 1, end))
    const rest = path.slice(end + 1)
    const nextRest = rest.startsWith(".") ? rest.slice(1) : rest
    const container = name ? readFrom(source, name) : source
    if (!Array.isArray(container) || !Number.isInteger(index) || index < 0 || index >= container.length) {
      return null
    }
    return nextRest ? readFrom(container[index], nextRest) : container[index]
  }
  if (dot === -1) {
    if (!source || typeof source !== "object" || Array.isArray(source)) {
      return null
    }
    if (!Object.prototype.hasOwnProperty.call(source, path)) {
      return null
    }
    return source[path]
  }
  const key = path.slice(0, dot)
  const rest = path.slice(dot + 1)
  if (!source || typeof source !== "object" || Array.isArray(source)) {
    return null
  }
  return readFrom(source[key], rest)
}

function truthy(value: unknown): boolean {
  if (value == null || value === false || value === "" || value === 0) {
    return false
  }
  return true
}

function same(left: unknown, right: unknown): boolean {
  if (left == null || right == null) {
    return left == null && right == null
  }
  if (typeof left === "number" && typeof right === "number") {
    return left === right
  }
  if (typeof left === "boolean" || typeof right === "boolean") {
    return left === right
  }
  return String(left) === String(right)
}

function num(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value
  }
  if (typeof value === "boolean") {
    return value ? 1 : 0
  }
  if (typeof value === "string" && value.trim() !== "" && Number.isFinite(Number(value))) {
    return Number(value)
  }
  return null
}

function add(left: unknown, right: unknown): unknown {
  if (typeof left === "string" || typeof right === "string") {
    return `${left ?? ""}${right ?? ""}`
  }
  const a = num(left)
  const b = num(right)
  if (a == null || b == null) {
    throw new Error("add")
  }
  return a + b
}

function sub(left: unknown, right: unknown): number {
  const a = num(left)
  const b = num(right)
  if (a == null || b == null) {
    throw new Error("sub")
  }
  return a - b
}

function mul(left: unknown, right: unknown): number {
  const a = num(left)
  const b = num(right)
  if (a == null || b == null) {
    throw new Error("mul")
  }
  return a * b
}

function div(left: unknown, right: unknown): number {
  const a = num(left)
  const b = num(right)
  if (a == null || b == null || b === 0) {
    throw new Error("div")
  }
  return a / b
}

function mod(left: unknown, right: unknown): number {
  const a = num(left)
  const b = num(right)
  if (a == null || b == null || b === 0) {
    throw new Error("mod")
  }
  return a % b
}
