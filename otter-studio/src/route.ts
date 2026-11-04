export type Route =
  | { page: 'monitor' }
  | { page: 'quality' }
  | { page: 'delivery'; id: string }
  | { page: 'templates' }
  | { page: 'recall' }
  | { page: 'pattern'; id: string }
  | { page: 'hits' }

export function parseHash(hash: string): Route {
  const parts = hash.replace(/^#/, '').split('/').filter(Boolean)
  if (parts[0] === 'monitor' && parts[1] === 'quality') {
    return { page: 'quality' }
  }
  if (parts[0] === 'monitor' && parts[1] === 'deliveries' && parts[2]) {
    return { page: 'delivery', id: decodeURIComponent(parts[2]) }
  }
  if (parts[0] === 'monitor') {
    return { page: 'monitor' }
  }
  if (parts[0] === 'recall' && parts[1] === 'hits') {
    return { page: 'hits' }
  }
  if (parts[0] === 'recall' && parts[1]) {
    return { page: 'pattern', id: decodeURIComponent(parts[1]) }
  }
  if (parts[0] === 'recall') {
    return { page: 'recall' }
  }
  return { page: 'templates' }
}

export function hrefFor(route: Route): string {
  switch (route.page) {
    case 'monitor':
      return '#/monitor'
    case 'quality':
      return '#/monitor/quality'
    case 'delivery':
      return `#/monitor/deliveries/${encodeURIComponent(route.id)}`
    case 'templates':
      return '#/templates'
    case 'recall':
      return '#/recall'
    case 'pattern':
      return `#/recall/${encodeURIComponent(route.id)}`
    case 'hits':
      return '#/recall/hits'
  }
}
