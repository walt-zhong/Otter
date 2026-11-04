import { describe, expect, it } from 'vitest'
import { formatCreatedAt, intentLabel, presentCatalog, presentFailure, presentSuccess, sampleMark } from './present'

describe('presentSuccess', () => {
  it('shopping sample true shows 示例 and a download href', () => {
    const view = presentSuccess({
      id: 'shop-1',
      intent: 'shopping',
      sample: true,
      sampleLabel: '示例',
      hash: 'abc',
      files: [
        'routes.json',
        'templates/list.json',
        'templates/detail.json',
        'data/list.json',
        'data/detail.json',
        'manifest.json',
      ],
    })

    expect(view.intent).toBe('shopping')
    expect(view.showSample).toBe(true)
    expect(sampleMark(view.showSample)).toBe('示例')
    expect(view.files).toEqual([
      'routes.json',
      'templates/list.json',
      'templates/detail.json',
      'data/list.json',
      'data/detail.json',
      'manifest.json',
    ])
    expect(view.downloadHref).toBe('/api/v1/bundles/shop-1')
  })

  it('clarify sample false does not show 示例', () => {
    const view = presentSuccess({
      id: 'clarify-1',
      intent: 'clarify',
      sample: false,
      sampleLabel: '',
      hash: 'def',
    })

    expect(view.intent).toBe('clarify')
    expect(view.showSample).toBe(false)
    expect(sampleMark(view.showSample)).toBeNull()
    expect(view.downloadHref).toBe('/api/v1/bundles/clarify-1')
  })
})

describe('presentCatalog', () => {
  it('maps a shopping record into the admin row', () => {
    const items = presentCatalog({
      items: [
        {
          id: 'shop-1',
          query: '买个手机壳',
          intent: 'shopping.browse',
          sample: true,
          sampleLabel: '示例',
          hash: 'abc',
          createdAt: '2026-11-04T12:00:00Z',
          files: ['routes.json', 'templates/list.json'],
        },
      ],
    })

    expect(items).not.toBeNull()
    expect(items?.[0]?.intentLabel).toBe('购物')
    expect(items?.[0]?.kind).toBe('示例')
    expect(items?.[0]?.files[1]).toEqual({ name: 'templates/list.json', label: '列表模版' })
    expect(items?.[0]?.downloadHref).toBe('/api/v1/bundles/shop-1')
    expect(intentLabel('clarify')).toBe('澄清')
  })

  it('rejects a catalog that is missing items', () => {
    expect(presentCatalog({})).toBeNull()
    expect(formatCreatedAt('not-a-date')).toBe('not-a-date')
  })
})

describe('presentFailure', () => {
  it('failure message is shown and downloadHref is null', () => {
    const view = presentFailure({
      code: 'invalid_query',
      message: '查询不能为空',
    })

    expect(view.message).toBe('查询不能为空')
    expect(view.downloadHref).toBeNull()
  })
})
