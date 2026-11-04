import { useEffect, useState } from 'react'
import './App.css'
import { DeliveryDetail, MonitorOverview, MonitorQuality } from './MonitorPages'
import { PatternDetail, RecallHits, RecallLibrary } from './RecallPages'
import TemplatesPage from './TemplatesPage'
import { hrefFor, parseHash, type Route } from './route'

const NAV: Array<{ label: string; items: Array<{ id: string; label: string; route: Route }> }> = [
  {
    label: '监控',
    items: [
      { id: 'monitor', label: '总览', route: { page: 'monitor' } },
      { id: 'quality', label: '端上质量', route: { page: 'quality' } },
    ],
  },
  {
    label: '模版',
    items: [{ id: 'templates', label: '签名包', route: { page: 'templates' } }],
  },
  {
    label: '召回',
    items: [
      { id: 'recall', label: '模版库', route: { page: 'recall' } },
      { id: 'hits', label: '命中记录', route: { page: 'hits' } },
    ],
  },
]

function isActive(route: Route, id: string): boolean {
  if (id === 'monitor') {
    return route.page === 'monitor' || route.page === 'delivery'
  }
  if (id === 'quality') {
    return route.page === 'quality'
  }
  if (id === 'templates') {
    return route.page === 'templates'
  }
  if (id === 'recall') {
    return route.page === 'recall' || route.page === 'pattern'
  }
  return route.page === 'hits'
}

export default function App() {
  const [route, setRoute] = useState<Route>(() => parseHash(window.location.hash))
  const [serviceUp, setServiceUp] = useState<boolean | null>(null)

  useEffect(() => {
    if (!window.location.hash) {
      window.location.replace('#/templates')
    }
    const sync = () => setRoute(parseHash(window.location.hash))
    window.addEventListener('hashchange', sync)
    return () => window.removeEventListener('hashchange', sync)
  }, [])

  useEffect(() => {
    fetch('/api/v1/health')
      .then((response) => setServiceUp(response.ok))
      .catch(() => setServiceUp(false))
  }, [])

  function navigate(next: Route) {
    const href = hrefFor(next)
    if (window.location.hash === href) {
      setRoute(next)
      return
    }
    window.location.hash = href
  }

  return (
    <div className="shell">
      <aside className="rail">
        <div className="brand">
          <span className="brand-mark" aria-hidden="true">
            Ot
          </span>
          <div>
            <p className="brand-name">Otter</p>
            <p className="brand-sub">管理后台</p>
          </div>
        </div>
        <nav className="nav-scroll" aria-label="后台目录">
          {NAV.map((group) => (
            <div key={group.label}>
              <p className="rail-label">{group.label}</p>
              <div className="nav-links">
                {group.items.map((item) => (
                  <button
                    key={item.id}
                    type="button"
                    className={isActive(route, item.id) ? 'nav-link nav-link-active' : 'nav-link'}
                    aria-current={isActive(route, item.id) ? 'page' : undefined}
                    onClick={() => navigate(item.route)}
                  >
                    {item.label}
                  </button>
                ))}
              </div>
            </div>
          ))}
        </nav>
        <div className="rail-foot">
          <p className={serviceUp ? 'status status-up' : 'status'}>
            <span className="status-dot" aria-hidden="true" />
            {serviceUp === null ? '正在检查服务' : serviceUp ? '生成服务可用' : '生成服务未连接'}
          </p>
          <p className="rail-note">签名包来自生成服务。监控和召回仍是示例页。</p>
        </div>
      </aside>
      <main className="workspace">
        {route.page === 'monitor' ? <MonitorOverview onNavigate={navigate} /> : null}
        {route.page === 'quality' ? <MonitorQuality /> : null}
        {route.page === 'delivery' ? <DeliveryDetail id={route.id} onNavigate={navigate} /> : null}
        {route.page === 'templates' ? <TemplatesPage onOpenRecall={() => navigate({ page: 'recall' })} /> : null}
        {route.page === 'recall' ? <RecallLibrary onNavigate={navigate} /> : null}
        {route.page === 'pattern' ? <PatternDetail id={route.id} onNavigate={navigate} /> : null}
        {route.page === 'hits' ? <RecallHits onNavigate={navigate} /> : null}
      </main>
    </div>
  )
}
