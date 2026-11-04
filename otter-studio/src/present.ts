export const FIXED_FILES = [
  'routes.json',
  'templates/list.json',
  'templates/detail.json',
  'data/list.json',
  'data/detail.json',
  'manifest.json',
] as const

export const SAMPLE_TEXT = '示例'

export interface GenerateSuccessBody {
  id: string
  intent: string
  sample: boolean
  sampleLabel?: string
  hash?: string
  files?: string[]
}

export interface GenerateFailureBody {
  code?: string
  message?: string
}

export interface SuccessPresentation {
  intent: string
  showSample: boolean
  files: string[]
  downloadHref: string
}

export interface FailurePresentation {
  message: string
  downloadHref: null
}

export function presentSuccess(body: GenerateSuccessBody): SuccessPresentation {
  return {
    intent: body.intent,
    showSample: body.sample === true,
    files: body.files ?? [...FIXED_FILES],
    downloadHref: `/api/v1/bundles/${body.id}`,
  }
}

export function presentFailure(body: GenerateFailureBody): FailurePresentation {
  return {
    message: body.message ?? '',
    downloadHref: null,
  }
}

export function sampleMark(showSample: boolean): typeof SAMPLE_TEXT | null {
  return showSample ? SAMPLE_TEXT : null
}

const FILE_LABELS: Record<string, string> = {
  'routes.json': '页面路由',
  'templates/list.json': '列表模版',
  'templates/detail.json': '详情模版',
  'data/list.json': '列表数据',
  'data/detail.json': '详情数据',
  'manifest.json': '签名清单',
}

export interface CatalogFile {
  name: string
  label: string
}

export interface CatalogItem {
  id: string
  query: string
  intent: string
  intentLabel: string
  sample: boolean
  kind: string
  hash: string
  files: CatalogFile[]
  createdAt: string
  createdLabel: string
  downloadHref: string
}

export function intentLabel(intent: string): string {
  if (intent === 'shopping.browse') {
    return '购物'
  }
  if (intent === 'clarify') {
    return '澄清'
  }
  return intent
}

export function fileLabel(name: string): string {
  return FILE_LABELS[name] ?? name
}

export function formatCreatedAt(iso: string): string {
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) {
    return iso
  }
  const month = date.getMonth() + 1
  const day = date.getDate()
  const hour = String(date.getHours()).padStart(2, '0')
  const minute = String(date.getMinutes()).padStart(2, '0')
  return `${month}月${day}日 ${hour}:${minute}`
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function kindOf(sample: boolean, intent: string, sampleLabel: string): string {
  if (sample) {
    return sampleLabel !== '' ? sampleLabel : SAMPLE_TEXT
  }
  if (intent === 'clarify') {
    return '澄清'
  }
  return '正式'
}

function presentCatalogItem(value: unknown): CatalogItem | null {
  if (!isRecord(value)) {
    return null
  }
  if (typeof value.id !== 'string' || value.id === '') {
    return null
  }
  if (typeof value.query !== 'string') {
    return null
  }
  if (typeof value.intent !== 'string' || value.intent === '') {
    return null
  }
  if (typeof value.sample !== 'boolean') {
    return null
  }
  if (typeof value.hash !== 'string' || value.hash === '') {
    return null
  }
  if (typeof value.createdAt !== 'string' || value.createdAt === '') {
    return null
  }
  const sampleLabel = typeof value.sampleLabel === 'string' ? value.sampleLabel : ''
  const names = value.files === undefined ? [...FIXED_FILES] : value.files
  if (!Array.isArray(names) || !names.every((name) => typeof name === 'string' && name !== '')) {
    return null
  }
  return {
    id: value.id,
    query: value.query,
    intent: value.intent,
    intentLabel: intentLabel(value.intent),
    sample: value.sample,
    kind: kindOf(value.sample, value.intent, sampleLabel),
    hash: value.hash,
    files: names.map((name) => ({ name, label: fileLabel(name) })),
    createdAt: value.createdAt,
    createdLabel: formatCreatedAt(value.createdAt),
    downloadHref: `/api/v1/bundles/${value.id}`,
  }
}

export function presentCatalog(value: unknown): CatalogItem[] | null {
  if (!isRecord(value) || !Array.isArray(value.items)) {
    return null
  }
  const items: CatalogItem[] = []
  for (const item of value.items) {
    const presented = presentCatalogItem(item)
    if (!presented) {
      return null
    }
    items.push(presented)
  }
  return items
}
