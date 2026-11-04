import { useEffect, useState } from 'react'
import { HITS, PATTERNS, patternById, type PatternSample } from './mock'
import { intentLabel } from './present'
import type { Route } from './route'

function SampleBanner() {
  return <p className="banner sample-banner">示例数据。召回库还没有建立，这些条目用来看页面，不会参与生成。</p>
}

export function RecallLibrary({ onNavigate }: { onNavigate: (route: Route) => void }) {
  return (
    <>
      <header className="topbar">
        <div>
          <h1>模版库</h1>
          <p className="count">给下次生成当例子的结构，不含某一次的商品数据</p>
        </div>
      </header>
      <SampleBanner />
      <section className="catalog" aria-label="召回模版">
        <table>
          <thead>
            <tr>
              <th>名称</th>
              <th>意图</th>
              <th>页面</th>
              <th>状态</th>
            </tr>
          </thead>
          <tbody>
            {PATTERNS.map((item) => (
              <tr key={item.id}>
                <td>
                  <button type="button" className="query" onClick={() => onNavigate({ page: 'pattern', id: item.id })}>
                    {item.name}
                  </button>
                </td>
                <td>{intentLabel(item.intent)}</td>
                <td>{item.pages.join('、')}</td>
                <td>
                  <span className={item.enabled ? 'chip chip-intent' : 'chip'}>{item.enabled ? '启用' : '停用'}</span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </>
  )
}

export function PatternDetail({ id, onNavigate }: { id: string; onNavigate: (route: Route) => void }) {
  const pattern = patternById(id)
  if (!pattern) {
    return (
      <>
        <header className="topbar">
          <div>
            <h1>结构</h1>
            <p className="count">没有这条示例</p>
          </div>
        </header>
        <button type="button" className="text-button" onClick={() => onNavigate({ page: 'recall' })}>
          返回模版库
        </button>
      </>
    )
  }
  return <PatternBody pattern={pattern} onNavigate={onNavigate} />
}

function PatternBody({ pattern, onNavigate }: { pattern: PatternSample; onNavigate: (route: Route) => void }) {
  const [enabled, setEnabled] = useState(pattern.enabled)
  useEffect(() => {
    setEnabled(pattern.enabled)
  }, [pattern])

  return (
    <>
      <header className="topbar">
        <div>
          <p className="count">召回结构</p>
          <h1>{pattern.name}</h1>
        </div>
        <button type="button" className="ghost" onClick={() => onNavigate({ page: 'recall' })}>
          返回模版库
        </button>
      </header>
      <SampleBanner />
      <section className="panel">
        <div className="chips">
          <span className="chip chip-intent">{intentLabel(pattern.intent)}</span>
          <span className={enabled ? 'chip chip-intent' : 'chip'}>{enabled ? '启用' : '停用'}</span>
        </div>
        <p className="dialog-lead">{pattern.note}</p>
        <dl className="facts">
          <div>
            <dt>页面</dt>
            <dd>{pattern.pages.join('、')}</dd>
          </div>
          <div>
            <dt>节点</dt>
            <dd className="token-row">
              {pattern.nodes.map((node) => (
                <code key={node}>{node}</code>
              ))}
            </dd>
          </div>
          <div>
            <dt>绑定</dt>
            <dd className="token-row">
              {pattern.bindings.map((binding) => (
                <code key={binding}>{binding}</code>
              ))}
            </dd>
          </div>
        </dl>
        <button type="button" className="primary" onClick={() => setEnabled((value) => !value)}>
          {enabled ? '停用' : '启用'}
        </button>
        <p className="count">只改这个页面上的示例，不会写入服务，也不会影响下一次生成。</p>
      </section>
    </>
  )
}

export function RecallHits({ onNavigate }: { onNavigate: (route: Route) => void }) {
  return (
    <>
      <header className="topbar">
        <div>
          <h1>命中记录</h1>
          <p className="count">哪次生成参考了哪条结构，最后有没有通过校验</p>
        </div>
      </header>
      <SampleBanner />
      <section className="catalog" aria-label="命中记录">
        <table>
          <thead>
            <tr>
              <th>查询</th>
              <th>结构</th>
              <th>顺序</th>
              <th>结果</th>
            </tr>
          </thead>
          <tbody>
            {HITS.map((hit) => {
              const pattern = patternById(hit.patternId)
              return (
                <tr key={hit.id}>
                  <td>{hit.query}</td>
                  <td>
                    <button
                      type="button"
                      className="query"
                      onClick={() => onNavigate({ page: 'pattern', id: hit.patternId })}
                    >
                      {pattern?.name ?? hit.patternId}
                    </button>
                  </td>
                  <td>{hit.rank}</td>
                  <td>{hit.note}</td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </section>
    </>
  )
}
