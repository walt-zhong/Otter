import { useMemo, useState } from 'react'
import {
  DELIVERIES,
  filterDeliveries,
  filterEvents,
  NODE_USAGE,
  SAMPLE_EVENTS,
  SAMPLE_RANGE,
  tally,
  type SampleFilter,
  type SampleIntent,
} from './mock'
import { intentLabel } from './present'
import type { Route } from './route'

type PlatformFilter = SampleFilter['platform']

function Filters({
  platform,
  intent,
  onPlatform,
  onIntent,
}: {
  platform: PlatformFilter
  intent: SampleFilter['intent']
  onPlatform: (value: PlatformFilter) => void
  onIntent: (value: SampleFilter['intent']) => void
}) {
  const platforms: Array<[PlatformFilter, string]> = [
    ['all', '全部端'],
    ['Android', 'Android'],
    ['iOS', 'iOS'],
  ]
  const intents: Array<[SampleFilter['intent'], string]> = [
    ['all', '全部意图'],
    ['shopping.browse', '购物'],
    ['clarify', '澄清'],
  ]
  return (
    <div className="toolbar">
      <div className="filters" role="group" aria-label="按端筛选">
        {platforms.map(([id, label]) => (
          <button
            key={id}
            type="button"
            className={platform === id ? 'filter filter-active' : 'filter'}
            aria-pressed={platform === id}
            onClick={() => onPlatform(id)}
          >
            {label}
          </button>
        ))}
      </div>
      <div className="filters" role="group" aria-label="按意图筛选">
        {intents.map(([id, label]) => (
          <button
            key={id}
            type="button"
            className={intent === id ? 'filter filter-active' : 'filter'}
            aria-pressed={intent === id}
            onClick={() => onIntent(id)}
          >
            {label}
          </button>
        ))}
      </div>
    </div>
  )
}

function useSampleFilter() {
  const [platform, setPlatform] = useState<PlatformFilter>('all')
  const [intent, setIntent] = useState<SampleFilter['intent']>('all')
  const filter = useMemo(() => ({ platform, intent }), [platform, intent])
  const summary = useMemo(() => tally(filterEvents(SAMPLE_EVENTS, filter)), [filter])
  return { platform, intent, setPlatform, setIntent, filter, summary }
}

function SampleBanner() {
  return <p className="banner sample-banner">示例数据。端上还没有上报，这些数字用来看页面，不是线上结果。</p>
}

function rateLabel(success: number, total: number): string {
  if (total === 0) {
    return '—'
  }
  return `${Math.round((success / total) * 100)}%`
}

export function MonitorOverview({ onNavigate }: { onNavigate: (route: Route) => void }) {
  const { platform, intent, setPlatform, setIntent, filter, summary } = useSampleFilter()
  const deliveries = filterDeliveries(filter)
  const maxDay = Math.max(1, ...summary.days.map((day) => day.success + day.fail))

  return (
    <>
      <header className="topbar">
        <div>
          <h1>总览</h1>
          <p className="count">近 7 日 · {SAMPLE_RANGE}</p>
        </div>
      </header>
      <SampleBanner />
      <Filters platform={platform} intent={intent} onPlatform={setPlatform} onIntent={setIntent} />
      {summary.total === 0 ? (
        <div className="panel empty-panel">
          <p>这个筛选下没有上报。</p>
          <p>iOS 还没有接入签名包，示例里也不编 iOS 数字。</p>
        </div>
      ) : (
        <>
          <section className="stat-grid" aria-label="近 7 日结果">
            <article className="stat">
              <b>{summary.total}</b>
              <span>打开</span>
            </article>
            <article className="stat">
              <b>{summary.success}</b>
              <span>画出来</span>
            </article>
            <article className="stat">
              <b className="stat-fail">{summary.fail}</b>
              <span>失败</span>
            </article>
            <article className="stat">
              <b>{rateLabel(summary.success, summary.total)}</b>
              <span>成功率</span>
            </article>
          </section>

          <section className="panel">
            <div className="panel-head">
              <h2>每天打开</h2>
              <p className="legend">
                <i className="swatch swatch-ok" /> 成功
                <i className="swatch swatch-bad" /> 失败
              </p>
            </div>
            <div className="bars">
              {summary.days.map((day) => (
                <div className="bar-row" key={day.day}>
                  <span>{day.day}</span>
                  <div
                    className="bar-track"
                    role="img"
                    aria-label={`${day.day} 成功 ${day.success}，失败 ${day.fail}`}
                  >
                    <span className="bar-ok" style={{ width: `${(day.success / maxDay) * 100}%` }} />
                    <span className="bar-bad" style={{ width: `${(day.fail / maxDay) * 100}%` }} />
                  </div>
                  <span className="bar-count">{day.success + day.fail}</span>
                </div>
              ))}
            </div>
          </section>

          <section className="catalog" aria-label="失败原因">
            <h2 className="section-title">失败原因</h2>
            <table>
              <thead>
                <tr>
                  <th>原因</th>
                  <th>阶段</th>
                  <th>次数</th>
                </tr>
              </thead>
              <tbody>
                {summary.reasons.map((reason) => (
                  <tr key={reason.result}>
                    <td>{reason.label}</td>
                    <td>{reason.stage}</td>
                    <td>{reason.count}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>

          <section className="catalog" aria-label="最近下发">
            <h2 className="section-title">最近下发</h2>
            <table>
              <thead>
                <tr>
                  <th>查询</th>
                  <th>意图</th>
                  <th>结果</th>
                  <th>时间</th>
                </tr>
              </thead>
              <tbody>
                {deliveries.map((item) => (
                  <tr key={item.id}>
                    <td>
                      <button type="button" className="query" onClick={() => onNavigate({ page: 'delivery', id: item.id })}>
                        {item.query}
                      </button>
                    </td>
                    <td>{intentLabel(item.intent)}</td>
                    <td>{item.failStep ?? '画出来'}</td>
                    <td className="when">{item.at}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
        </>
      )}
    </>
  )
}

export function MonitorQuality() {
  const { platform, intent, setPlatform, setIntent, summary } = useSampleFilter()
  const maxNode = NODE_USAGE[0]?.[2] ?? 1
  const showNodes = platform !== 'iOS' && intent === 'all'

  return (
    <>
      <header className="topbar">
        <div>
          <h1>端上质量</h1>
          <p className="count">失败落在哪一版，节点被用了多少次</p>
        </div>
      </header>
      <SampleBanner />
      <Filters platform={platform} intent={intent} onPlatform={setPlatform} onIntent={setIntent} />
      {summary.total === 0 ? (
        <div className="panel empty-panel">
          <p>这个筛选下没有上报。</p>
          <p>iOS 还没有接入签名包。</p>
        </div>
      ) : (
        <>
          <section className="catalog" aria-label="按版本">
            <h2 className="section-title">版本</h2>
            <table>
              <thead>
                <tr>
                  <th>SDK</th>
                  <th>画出来</th>
                  <th>失败</th>
                  <th>成功率</th>
                </tr>
              </thead>
              <tbody>
                {summary.versions.map((item) => (
                  <tr key={item.version}>
                    <td>Android {item.version}</td>
                    <td>{item.success}</td>
                    <td>{item.fail}</td>
                    <td>{rateLabel(item.success, item.success + item.fail)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
          <section className="catalog" aria-label="失败原因">
            <h2 className="section-title">失败原因</h2>
            <table>
              <thead>
                <tr>
                  <th>原因</th>
                  <th>阶段</th>
                  <th>次数</th>
                </tr>
              </thead>
              <tbody>
                {summary.reasons.map((reason) => (
                  <tr key={reason.result}>
                    <td>{reason.label}</td>
                    <td>{reason.stage}</td>
                    <td>{reason.count}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
        </>
      )}
      {!showNodes && platform !== 'iOS' ? (
        <p className="count node-note">节点统计没有按意图拆开。选「全部意图」时显示。</p>
      ) : null}
      {showNodes ? (
        <section className="panel">
          <h2>节点</h2>
          <p className="count">近 7 日 Android 示例。次数是节点出现次数，不是打开次数。</p>
          <div className="bars bars-wide">
            {NODE_USAGE.map(([name, label, count]) => (
              <div className="bar-row" key={name}>
                <span>
                  {label} <code>{name}</code>
                </span>
                <div className="bar-track" role="img" aria-label={`${label} ${count} 次`}>
                  <span className="bar-ok" style={{ width: `${maxNode === 0 ? 0 : (count / maxNode) * 100}%` }} />
                </div>
                <span className="bar-count">{count}</span>
              </div>
            ))}
          </div>
        </section>
      ) : null}
    </>
  )
}

export function DeliveryDetail({ id, onNavigate }: { id: string; onNavigate: (route: Route) => void }) {
  const item = DELIVERIES.find((delivery) => delivery.id === id)
  if (!item) {
    return (
      <>
        <header className="topbar">
          <div>
            <h1>单次下发</h1>
            <p className="count">没有这条示例</p>
          </div>
        </header>
        <button type="button" className="text-button" onClick={() => onNavigate({ page: 'monitor' })}>
          返回总览
        </button>
      </>
    )
  }
  return (
    <>
      <header className="topbar">
        <div>
          <p className="count">单次下发</p>
          <h1>{item.query}</h1>
        </div>
        <button type="button" className="ghost" onClick={() => onNavigate({ page: 'monitor' })}>
          返回总览
        </button>
      </header>
      <SampleBanner />
      <section className="panel">
        <dl className="facts facts-grid">
          <div>
            <dt>意图</dt>
            <dd>{intentLabel(item.intent as SampleIntent)}</dd>
          </div>
          <div>
            <dt>端</dt>
            <dd>Android {item.version}</dd>
          </div>
          <div>
            <dt>打开</dt>
            <dd>{item.opens} 次</dd>
          </div>
          <div>
            <dt>结果</dt>
            <dd>{item.failStep ?? '画出来'}</dd>
          </div>
          <div>
            <dt>时间</dt>
            <dd>{item.at}</dd>
          </div>
          <div>
            <dt>示例编号</dt>
            <dd>
              <code>{item.id}</code>
            </dd>
          </div>
        </dl>
        <p className="count">这是示例下发，不是生成服务里的签名包，不能下载。</p>
      </section>
    </>
  )
}
