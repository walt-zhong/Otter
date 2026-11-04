import { FormEvent, useEffect, useId, useMemo, useRef, useState } from 'react'
import { presentCatalog, presentFailure, type CatalogItem } from './present'

type IntentFilter = 'all' | 'shopping.browse' | 'clarify'

const FILTERS: { id: IntentFilter; label: string }[] = [
  { id: 'all', label: '全部' },
  { id: 'shopping.browse', label: '购物' },
  { id: 'clarify', label: '澄清' },
]

function messageFrom(value: unknown): string {
  if (typeof value === 'object' && value !== null && 'message' in value && typeof value.message === 'string') {
    return value.message
  }
  return '请求失败'
}

async function readJSON(response: Response): Promise<unknown> {
  try {
    return await response.json()
  } catch {
    return null
  }
}

export default function TemplatesPage({ onOpenRecall }: { onOpenRecall: () => void }) {
  const [items, setItems] = useState<CatalogItem[]>([])
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [loadError, setLoadError] = useState<string | null>(null)
  const [filter, setFilter] = useState<IntentFilter>('all')
  const [keyword, setKeyword] = useState('')
  const [composerOpen, setComposerOpen] = useState(false)
  const [query, setQuery] = useState('')
  const [pending, setPending] = useState(false)
  const [composerError, setComposerError] = useState<string | null>(null)
  const generateRef = useRef<HTMLButtonElement>(null)
  const queryRef = useRef<HTMLTextAreaElement>(null)
  const titleId = useId()

  async function loadCatalog(preferId?: string) {
    setLoading(true)
    setLoadError(null)
    try {
      const listResponse = await fetch('/api/v1/bundles')
      const body = await readJSON(listResponse)
      if (!listResponse.ok) {
        setLoadError(messageFrom(body) || '模版列表读取失败')
        return
      }
      const catalog = presentCatalog(body)
      if (!catalog) {
        setLoadError('模版列表格式不正确')
        return
      }
      setItems(catalog)
      setSelectedId((current) => {
        const wanted = preferId ?? current
        if (wanted && catalog.some((item) => item.id === wanted)) {
          return wanted
        }
        return catalog[0]?.id ?? null
      })
    } catch {
      setLoadError('连不上生成服务。先在 otter-harbor 启动服务。')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void loadCatalog()
  }, [])

  useEffect(() => {
    if (!composerOpen) {
      return
    }
    queryRef.current?.focus()
    function onKey(event: KeyboardEvent) {
      if (event.key === 'Escape' && !pending) {
        setComposerOpen(false)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [composerOpen, pending])

  const visible = useMemo(() => {
    const text = keyword.trim()
    return items.filter((item) => {
      if (filter !== 'all' && item.intent !== filter) {
        return false
      }
      if (text === '') {
        return true
      }
      return item.query.includes(text) || item.id.includes(text)
    })
  }, [filter, items, keyword])

  const selected = items.find((item) => item.id === selectedId) ?? null
  const queryLength = Array.from(query).length

  function openComposer() {
    setComposerError(null)
    setComposerOpen(true)
  }

  function closeComposer() {
    if (pending) {
      return
    }
    setComposerOpen(false)
    generateRef.current?.focus()
  }

  async function onGenerate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (pending) {
      return
    }
    if (query.trim() === '') {
      setComposerError('请输入查询')
      return
    }
    if (queryLength > 200) {
      setComposerError('查询长度须在 1 到 200 之间')
      return
    }
    setPending(true)
    setComposerError(null)
    try {
      const response = await fetch('/api/v1/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query }),
      })
      const body = await readJSON(response)
      if (!response.ok || body === null) {
        setComposerError(presentFailure({ message: messageFrom(body) }).message || '请求失败')
        return
      }
      const id = typeof body === 'object' && body !== null && 'id' in body && typeof body.id === 'string' ? body.id : ''
      if (id === '') {
        setComposerError('响应格式不正确')
        return
      }
      setQuery('')
      setComposerOpen(false)
      await loadCatalog(id)
      generateRef.current?.focus()
    } catch {
      setComposerError('网络请求失败')
    } finally {
      setPending(false)
    }
  }

  return (
    <>
      <header className="topbar">
        <div>
          <h1>签名包</h1>
          <p className="count">{loading ? '正在读取' : `共 ${items.length} 条`}</p>
        </div>
        <button ref={generateRef} className="primary" type="button" onClick={openComposer}>
          生成模版
        </button>
      </header>

      {loadError ? <p className="banner">{loadError}</p> : null}

      <div className="toolbar">
        <label className="search">
          <span className="sr-only">搜索模版</span>
          <input
            type="search"
            value={keyword}
            placeholder="搜索查询或编号"
            onChange={(event) => setKeyword(event.target.value)}
          />
        </label>
        <div className="filters" role="group" aria-label="按意图筛选">
          {FILTERS.map((item) => (
            <button
              key={item.id}
              type="button"
              className={filter === item.id ? 'filter filter-active' : 'filter'}
              aria-pressed={filter === item.id}
              onClick={() => setFilter(item.id)}
            >
              {item.label}
            </button>
          ))}
        </div>
      </div>

      <div className="board">
        <section className="catalog" aria-label="模版列表">
          {loading && items.length === 0 ? <p className="empty">正在读取模版</p> : null}
          {!loading && items.length === 0 ? (
            <div className="empty">
              <p>还没有模版。</p>
              <p>写一句查询，生成可下发的签名包。</p>
              <button className="primary" type="button" onClick={openComposer}>
                生成模版
              </button>
            </div>
          ) : null}
          {!loading && items.length > 0 && visible.length === 0 ? <p className="empty">没有符合条件的模版。</p> : null}
          {visible.length > 0 ? (
            <table>
              <thead>
                <tr>
                  <th>查询</th>
                  <th>意图</th>
                  <th>标记</th>
                  <th>时间</th>
                </tr>
              </thead>
              <tbody>
                {visible.map((item) => (
                  <tr
                    key={item.id}
                    className={item.id === selectedId ? 'row-selected' : undefined}
                    onClick={() => setSelectedId(item.id)}
                  >
                    <td>
                      <button type="button" className="query" onClick={() => setSelectedId(item.id)}>
                        {item.query}
                      </button>
                    </td>
                    <td>{item.intentLabel}</td>
                    <td>
                      <span className={item.sample ? 'chip chip-sample' : 'chip'}>{item.kind}</span>
                    </td>
                    <td className="when">{item.createdLabel}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : null}
        </section>

        <Inspector item={selected} hasItems={items.length > 0} onOpenRecall={onOpenRecall} />
      </div>

      {composerOpen ? (
        <div className="backdrop" onMouseDown={closeComposer}>
          <form
            className="dialog"
            role="dialog"
            aria-modal="true"
            aria-labelledby={titleId}
            onMouseDown={(event) => event.stopPropagation()}
            onSubmit={onGenerate}
          >
            <h2 id={titleId}>生成模版</h2>
            <p className="dialog-lead">购物类查询会生成带「示例」的商品页。其他查询生成澄清页。模版和数据打进同一个签名包。</p>
            <label htmlFor="query">查询</label>
            <textarea
              ref={queryRef}
              id="query"
              name="query"
              rows={4}
              maxLength={200}
              value={query}
              placeholder="例如：买个手机壳"
              onChange={(event) => setQuery(event.target.value)}
            />
            <p className="counter">{queryLength} / 200</p>
            {composerError ? <p className="banner">{composerError}</p> : null}
            <div className="dialog-actions">
              <button type="button" className="ghost" onClick={closeComposer} disabled={pending}>
                取消
              </button>
              <button type="submit" className="primary" disabled={pending}>
                {pending ? '正在生成' : '生成'}
              </button>
            </div>
          </form>
        </div>
      ) : null}
    </>
  )
}

function Inspector({
  item,
  hasItems,
  onOpenRecall,
}: {
  item: CatalogItem | null
  hasItems: boolean
  onOpenRecall: () => void
}) {
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    setCopied(false)
  }, [item?.id])

  if (!item) {
    return (
      <aside className="inspector">
        <p className="empty">{hasItems ? '选择一条模版查看签名包。' : '生成后，这里显示包的意图、文件和下载。'}</p>
      </aside>
    )
  }

  const current = item

  async function copyId() {
    try {
      await navigator.clipboard.writeText(current.id)
      setCopied(true)
    } catch {
      setCopied(false)
    }
  }

  return (
    <aside className="inspector">
      <p className="inspector-kicker">签名包</p>
      <h2>{item.query}</h2>
      <div className="chips">
        <span className="chip chip-intent">{item.intentLabel}</span>
        <span className={item.sample ? 'chip chip-sample' : 'chip'}>{item.kind}</span>
      </div>
      <dl className="facts">
        <div>
          <dt>编号</dt>
          <dd>
            <code>{item.id}</code>
            <button type="button" className="text-button" onClick={() => void copyId()}>
              {copied ? '已复制' : '复制'}
            </button>
          </dd>
        </div>
        <div>
          <dt>时间</dt>
          <dd>{item.createdLabel}</dd>
        </div>
        <div>
          <dt>摘要</dt>
          <dd>
            <code className="hash">{item.hash}</code>
          </dd>
        </div>
        <div>
          <dt>来源</dt>
          <dd>尚未记录</dd>
        </div>
        <div>
          <dt>召回</dt>
          <dd>这次没有使用召回库</dd>
        </div>
      </dl>
      <h3>包内文件</h3>
      <ul className="files">
        {item.files.map((file) => (
          <li key={file.name}>
            <span>{file.label}</span>
            <code>{file.name}</code>
          </li>
        ))}
      </ul>
      <a className="primary download" href={item.downloadHref}>
        下载签名包
      </a>
      <button type="button" className="text-button recall-jump" onClick={onOpenRecall}>
        打开召回库示例
      </button>
    </aside>
  )
}
