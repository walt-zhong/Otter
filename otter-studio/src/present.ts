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
