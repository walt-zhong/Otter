import { FormEvent, useState } from 'react'
import './App.css'
import {
  presentFailure,
  presentSuccess,
  sampleMark,
  type FailurePresentation,
  type GenerateSuccessBody,
  type SuccessPresentation,
} from './present'

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null
}

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((item) => typeof item === 'string')
}

function isSuccessBody(value: unknown): value is GenerateSuccessBody {
  if (!isRecord(value)) {
    return false
  }
  if (typeof value.id !== 'string' || value.id === '') {
    return false
  }
  if (typeof value.intent !== 'string') {
    return false
  }
  if (typeof value.sample !== 'boolean') {
    return false
  }
  if (value.files !== undefined && !isStringArray(value.files)) {
    return false
  }
  return true
}

function messageFrom(value: unknown): string {
  if (isRecord(value) && typeof value.message === 'string') {
    return value.message
  }
  return '请求失败'
}

export default function App() {
  const [query, setQuery] = useState('')
  const [pending, setPending] = useState(false)
  const [localMessage, setLocalMessage] = useState<string | null>(null)
  const [success, setSuccess] = useState<SuccessPresentation | null>(null)
  const [failure, setFailure] = useState<FailurePresentation | null>(null)

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (pending) {
      return
    }
    if (query.trim() === '') {
      setLocalMessage('请输入查询')
      setSuccess(null)
      setFailure(null)
      return
    }

    setPending(true)
    setLocalMessage(null)
    setSuccess(null)
    setFailure(null)

    try {
      const response = await fetch('/api/v1/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query }),
      })
      let body: unknown
      try {
        body = await response.json()
      } catch {
        setFailure(presentFailure({ message: '请求失败' }))
        return
      }
      if (!response.ok) {
        setFailure(presentFailure({ message: messageFrom(body) }))
        return
      }
      if (!isSuccessBody(body)) {
        setFailure(presentFailure({ message: '响应格式不正确' }))
        return
      }
      setSuccess(presentSuccess(body))
    } catch {
      setFailure(presentFailure({ message: '网络请求失败' }))
    } finally {
      setPending(false)
    }
  }

  const mark = success ? sampleMark(success.showSample) : null

  return (
    <main className="page">
      <h1>调试控制台</h1>
      <form onSubmit={onSubmit}>
        <label htmlFor="query">查询</label>
        <input
          id="query"
          name="query"
          type="text"
          value={query}
          autoComplete="off"
          onChange={(event) => setQuery(event.target.value)}
        />
        <button type="submit" disabled={pending}>
          提交
        </button>
      </form>
      {localMessage ? <p className="notice">{localMessage}</p> : null}
      {failure ? <p className="notice">{failure.message}</p> : null}
      {success ? (
        <section className="result">
          <p>
            意图：<span>{success.intent}</span>
          </p>
          {mark ? <p className="sample">{mark}</p> : null}
          <ul>
            {success.files.map((name) => (
              <li key={name}>{name}</li>
            ))}
          </ul>
          <a href={success.downloadHref}>下载</a>
        </section>
      ) : null}
    </main>
  )
}
