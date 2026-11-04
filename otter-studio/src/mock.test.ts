import { describe, expect, it } from 'vitest'
import { filterEvents, SAMPLE_EVENTS, tally } from './mock'
import { parseHash } from './route'

describe('sample tally', () => {
  it('counts Android unknown-node failures and treats iOS as empty', () => {
    const android = tally(filterEvents(SAMPLE_EVENTS, { platform: 'Android', intent: 'all' }))
    const unknown = android.reasons.find((item) => item.result === 'unknown-node')
    expect(unknown?.count).toBe(11)
    expect(unknown?.stage).toBe('解析')
    expect(android.total).toBeGreaterThan(android.success)

    const ios = tally(filterEvents(SAMPLE_EVENTS, { platform: 'iOS', intent: 'all' }))
    expect(ios.total).toBe(0)
  })
})

describe('parseHash', () => {
  it('reads the admin sections', () => {
    expect(parseHash('')).toEqual({ page: 'templates' })
    expect(parseHash('#/monitor/quality')).toEqual({ page: 'quality' })
    expect(parseHash('#/monitor/deliveries/sample-shop-1')).toEqual({ page: 'delivery', id: 'sample-shop-1' })
    expect(parseHash('#/recall/shopping-card')).toEqual({ page: 'pattern', id: 'shopping-card' })
    expect(parseHash('#/recall/hits')).toEqual({ page: 'hits' })
  })
})
