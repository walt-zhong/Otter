export type SampleIntent = 'shopping.browse' | 'clarify'
export type SampleResult = 'ok' | 'bad-signature' | 'unknown-node' | 'bad-expression' | 'bad-zip' | 'image'
export type SamplePlatform = 'Android' | 'iOS'

export interface SampleEvent {
  day: string
  platform: SamplePlatform
  version: string
  intent: SampleIntent
  result: SampleResult
}

export interface SampleFilter {
  platform: 'all' | SamplePlatform
  intent: 'all' | SampleIntent
}

export interface DayTally {
  day: string
  success: number
  fail: number
}

export interface ReasonTally {
  result: SampleResult
  label: string
  stage: string
  count: number
}

export interface VersionTally {
  version: string
  success: number
  fail: number
}

export interface Tally {
  total: number
  success: number
  fail: number
  days: DayTally[]
  reasons: ReasonTally[]
  versions: VersionTally[]
}

const PLAN: Array<[string, SampleIntent, string, SampleResult, number]> = [
  ['10/29', 'shopping.browse', '1.4.2', 'ok', 28],
  ['10/29', 'shopping.browse', '1.4.0', 'ok', 8],
  ['10/29', 'shopping.browse', '1.4.0', 'unknown-node', 2],
  ['10/29', 'clarify', '1.4.2', 'ok', 6],
  ['10/30', 'shopping.browse', '1.4.2', 'ok', 24],
  ['10/30', 'shopping.browse', '1.4.2', 'image', 2],
  ['10/30', 'clarify', '1.4.2', 'ok', 9],
  ['10/31', 'shopping.browse', '1.4.2', 'ok', 30],
  ['10/31', 'shopping.browse', '1.4.0', 'bad-expression', 4],
  ['10/31', 'shopping.browse', '1.4.0', 'unknown-node', 3],
  ['10/31', 'clarify', '1.4.2', 'ok', 8],
  ['11/01', 'shopping.browse', '1.4.2', 'ok', 26],
  ['11/01', 'shopping.browse', '1.4.2', 'bad-signature', 2],
  ['11/01', 'clarify', '1.4.2', 'bad-zip', 1],
  ['11/01', 'clarify', '1.4.2', 'ok', 11],
  ['11/02', 'shopping.browse', '1.4.2', 'ok', 22],
  ['11/02', 'shopping.browse', '1.4.2', 'image', 3],
  ['11/02', 'clarify', '1.4.2', 'ok', 7],
  ['11/03', 'shopping.browse', '1.4.0', 'unknown-node', 6],
  ['11/03', 'shopping.browse', '1.4.2', 'ok', 34],
  ['11/03', 'shopping.browse', '1.4.2', 'bad-expression', 2],
  ['11/03', 'clarify', '1.4.2', 'ok', 12],
  ['11/04', 'shopping.browse', '1.4.2', 'ok', 14],
  ['11/04', 'shopping.browse', '1.4.2', 'image', 1],
  ['11/04', 'clarify', '1.4.2', 'ok', 5],
]

const RESULT_META: Record<SampleResult, { label: string; stage: string }> = {
  ok: { label: '成功', stage: '绘制' },
  'bad-signature': { label: '签名不符', stage: '校验' },
  'unknown-node': { label: '未知节点', stage: '解析' },
  'bad-expression': { label: '表达式不是整段', stage: '解析' },
  'bad-zip': { label: 'zip 无法打开', stage: '校验' },
  image: { label: '图片没有画出来', stage: '绘制' },
}

function expand(): SampleEvent[] {
  const events: SampleEvent[] = []
  for (const [day, intent, version, result, count] of PLAN) {
    for (let index = 0; index < count; index += 1) {
      events.push({ day, platform: 'Android', version, intent, result })
    }
  }
  return events
}

export const SAMPLE_EVENTS = expand()

export const SAMPLE_RANGE = '10/29–11/04'

export function resultLabel(result: SampleResult): string {
  return RESULT_META[result].label
}

export function filterEvents(events: SampleEvent[], filter: SampleFilter): SampleEvent[] {
  return events.filter((event) => {
    if (filter.platform !== 'all' && event.platform !== filter.platform) {
      return false
    }
    if (filter.intent !== 'all' && event.intent !== filter.intent) {
      return false
    }
    return true
  })
}

export function tally(events: SampleEvent[]): Tally {
  const dayOrder: string[] = []
  const days = new Map<string, DayTally>()
  const reasons = new Map<SampleResult, number>()
  const versions = new Map<string, VersionTally>()
  let success = 0
  for (const event of events) {
    let day = days.get(event.day)
    if (!day) {
      day = { day: event.day, success: 0, fail: 0 }
      days.set(event.day, day)
      dayOrder.push(event.day)
    }
    let version = versions.get(event.version)
    if (!version) {
      version = { version: event.version, success: 0, fail: 0 }
      versions.set(event.version, version)
    }
    if (event.result === 'ok') {
      success += 1
      day.success += 1
      version.success += 1
    } else {
      day.fail += 1
      version.fail += 1
      reasons.set(event.result, (reasons.get(event.result) ?? 0) + 1)
    }
  }
  const reasonRows: ReasonTally[] = [...reasons.entries()]
    .map(([result, count]) => ({
      result,
      label: RESULT_META[result].label,
      stage: RESULT_META[result].stage,
      count,
    }))
    .sort((left, right) => right.count - left.count)
  return {
    total: events.length,
    success,
    fail: events.length - success,
    days: dayOrder.map((day) => days.get(day) as DayTally),
    reasons: reasonRows,
    versions: [...versions.values()].sort((left, right) => right.fail - left.fail),
  }
}

export interface DeliverySample {
  id: string
  query: string
  intent: SampleIntent
  version: string
  opens: number
  failStep: string | null
  at: string
}

export const DELIVERIES: DeliverySample[] = [
  {
    id: 'sample-shop-1',
    query: '买个手机壳',
    intent: 'shopping.browse',
    version: '1.4.2',
    opens: 12,
    failStep: null,
    at: '11/04 20:41',
  },
  {
    id: 'sample-shop-2',
    query: '透明壳',
    intent: 'shopping.browse',
    version: '1.4.0',
    opens: 4,
    failStep: '解析 · 未知节点',
    at: '11/03 18:12',
  },
  {
    id: 'sample-shop-3',
    query: '皮革壳',
    intent: 'shopping.browse',
    version: '1.4.2',
    opens: 6,
    failStep: '绘制 · 图片没有画出来',
    at: '11/01 15:02',
  },
  {
    id: 'sample-clarify-1',
    query: '今天星期几',
    intent: 'clarify',
    version: '1.4.2',
    opens: 3,
    failStep: null,
    at: '11/02 09:20',
  },
]

export function filterDeliveries(filter: SampleFilter): DeliverySample[] {
  return DELIVERIES.filter((item) => filter.platform !== 'iOS' && (filter.intent === 'all' || item.intent === filter.intent))
}

export const NODE_USAGE: Array<[string, string, number]> = [
  ['text', '文本', 210],
  ['column', '纵向', 120],
  ['row', '横向', 86],
  ['image', '图片', 64],
  ['list', '列表', 40],
  ['spacer', '空白', 30],
  ['switch', '开关', 4],
  ['progress', '进度', 2],
  ['lottie', '动画', 2],
  ['input', '输入', 0],
  ['checkbox', '多选', 0],
  ['radio', '单选', 0],
]

export interface PatternSample {
  id: string
  name: string
  intent: SampleIntent
  pages: string[]
  nodes: string[]
  bindings: string[]
  enabled: boolean
  note: string
}

export const PATTERNS: PatternSample[] = [
  {
    id: 'shopping-card',
    name: '商品卡片',
    intent: 'shopping.browse',
    pages: ['list', 'detail'],
    nodes: ['column', 'row', 'text', 'image', 'list'],
    bindings: ['$products', '$sampleLabel', '$title', '$price', '$cover', '$note'],
    enabled: true,
    note: '列表是一张张卡片，详情可以滚动。从通过校验的购物包收录，不含商品图和价格。',
  },
  {
    id: 'clarify-note',
    name: '澄清说明',
    intent: 'clarify',
    pages: ['list'],
    nodes: ['column', 'text'],
    bindings: ['$message'],
    enabled: true,
    note: '只有一页说明，没有打开详情。',
  },
  {
    id: 'shopping-compact',
    name: '紧凑商品行',
    intent: 'shopping.browse',
    pages: ['list', 'detail'],
    nodes: ['column', 'row', 'text', 'image', 'list'],
    bindings: ['$products', '$title', '$price', '$cover'],
    enabled: false,
    note: '停用。横排列表校验不稳定，先不参与召回。',
  },
]

export interface HitSample {
  id: string
  query: string
  patternId: string
  rank: number
  passed: boolean
  bundleId: string
  note: string
}

export const HITS: HitSample[] = [
  {
    id: 'hit-1',
    query: '买个手机壳',
    patternId: 'shopping-card',
    rank: 1,
    passed: true,
    bundleId: 'sample-shop-1',
    note: '采用',
  },
  {
    id: 'hit-2',
    query: '买个手机壳',
    patternId: 'shopping-compact',
    rank: 2,
    passed: false,
    bundleId: 'sample-shop-1',
    note: '未采用，条目已停用',
  },
  {
    id: 'hit-3',
    query: '今天星期几',
    patternId: 'clarify-note',
    rank: 1,
    passed: true,
    bundleId: 'sample-clarify-1',
    note: '采用',
  },
  {
    id: 'hit-4',
    query: '透明壳',
    patternId: 'shopping-card',
    rank: 1,
    passed: true,
    bundleId: 'sample-shop-2',
    note: '采用。端上仍有一条未知节点失败',
  },
]

export function patternById(id: string): PatternSample | undefined {
  return PATTERNS.find((item) => item.id === id)
}
