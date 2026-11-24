// Allowlist of the two request shapes Core sends. Anything else is refused, so a leaked app token can't turn the
// server into a general-purpose Claude relay (no tools, no other models, bounded output):
// - answers (ClaudeProvider): the answer models, up to maxTokens, text and PDF blocks;
// - rulebook sorting (RulebookSorter, S14): the sort models (Haiku), up to sortMaxTokens, one user turn of text,
//   no document, thinking disabled.
// When Core starts sending a new field, add it here and to the tests.

export interface Limits {
  allowedModels: Set<string>
  maxTokens: number
  sortModels: Set<string>
  sortMaxTokens: number
}

export interface ValidRequest {
  model: string
  maxTokens: number
}

export class ValidationError extends Error {}

type Json = Record<string, unknown>

const isObject = (v: unknown): v is Json => typeof v === 'object' && v !== null && !Array.isArray(v)

function onlyKeys(obj: Json, allowed: readonly string[], where: string): void {
  for (const key of Object.keys(obj)) {
    if (!allowed.includes(key)) throw new ValidationError(`${where}: field "${key}" is not allowed`)
  }
}

function cacheControl(v: unknown, where: string): void {
  if (v === undefined) return
  if (!isObject(v) || v.type !== 'ephemeral') throw new ValidationError(`${where}.cache_control must be ephemeral`)
  onlyKeys(v, ['type', 'ttl'], `${where}.cache_control`)
  if (v.ttl !== undefined && v.ttl !== '5m' && v.ttl !== '1h') throw new ValidationError(`${where}.cache_control.ttl`)
}

function block(b: unknown, role: string, where: string): void {
  if (!isObject(b)) throw new ValidationError(`${where} must be an object`)
  if (b.type === 'text') {
    onlyKeys(b, ['type', 'text', 'cache_control'], where)
    if (typeof b.text !== 'string') throw new ValidationError(`${where}.text must be a string`)
  } else if (b.type === 'document' && role === 'user') {
    onlyKeys(b, ['type', 'source', 'title', 'citations', 'cache_control'], where)
    const s = b.source
    if (!isObject(s) || s.type !== 'base64' || s.media_type !== 'application/pdf' || typeof s.data !== 'string') {
      throw new ValidationError(`${where}.source must be a base64 PDF`)
    }
    onlyKeys(s, ['type', 'media_type', 'data'], `${where}.source`)
    if (b.title !== undefined && typeof b.title !== 'string') throw new ValidationError(`${where}.title`)
    if (b.citations !== undefined && !(isObject(b.citations) && typeof b.citations.enabled === 'boolean')) {
      throw new ValidationError(`${where}.citations`)
    }
  } else {
    throw new ValidationError(`${where}: block type "${String(b.type)}" is not allowed for ${role}`)
  }
  cacheControl(b.cache_control, where)
}

export function validate(body: unknown, limits: Limits): ValidRequest {
  if (!isObject(body)) throw new ValidationError('body must be a JSON object')
  const sort = typeof body.model === 'string' && limits.sortModels.has(body.model)
  return sort ? validateSort(body, limits) : validateAnswer(body, limits)
}

function maxTokensOf(body: Json, cap: number): number {
  const maxTokens = body.max_tokens
  if (typeof maxTokens !== 'number' || !Number.isInteger(maxTokens) || maxTokens < 1 || maxTokens > cap) {
    throw new ValidationError(`max_tokens must be an integer between 1 and ${cap}`)
  }
  return maxTokens
}

/** RulebookSorter: one user message of text (file names, titles, first-page text), small output, no PDF. */
function validateSort(body: Json, limits: Limits): ValidRequest {
  onlyKeys(body, ['model', 'max_tokens', 'stream', 'system', 'thinking', 'output_config', 'messages'], 'body')
  const maxTokens = maxTokensOf(body, limits.sortMaxTokens)
  if (body.stream !== true) throw new ValidationError('stream must be true')
  if (body.system !== undefined && typeof body.system !== 'string') throw new ValidationError('system must be a string')
  if (body.thinking !== undefined) {
    if (!isObject(body.thinking) || body.thinking.type !== 'disabled') throw new ValidationError('thinking must be disabled')
    onlyKeys(body.thinking, ['type'], 'thinking')
  }
  outputConfig(body.output_config)
  const messages = body.messages
  if (!Array.isArray(messages) || messages.length !== 1) throw new ValidationError('messages must be one user message')
  const m = messages[0]
  if (!isObject(m) || m.role !== 'user') throw new ValidationError('messages[0] must be a user message')
  onlyKeys(m, ['role', 'content'], 'messages[0]')
  if (typeof m.content !== 'string') {
    if (!Array.isArray(m.content) || m.content.length === 0) throw new ValidationError('messages[0].content must be text')
    m.content.forEach((b, j) => {
      const where = `messages[0].content[${j}]`
      if (!isObject(b) || b.type !== 'text') throw new ValidationError(`${where}: only text blocks are allowed`)
      block(b, 'user', where)
    })
  }
  return { model: body.model as string, maxTokens }
}

function outputConfig(oc: unknown): void {
  if (oc === undefined) return
  if (!isObject(oc)) throw new ValidationError('output_config must be an object')
  onlyKeys(oc, ['effort', 'format'], 'output_config')
  if (oc.effort !== undefined && !['low', 'medium', 'high'].includes(oc.effort as string)) {
    throw new ValidationError('output_config.effort must be low, medium or high')
  }
  if (oc.format !== undefined) {
    const f = oc.format
    if (!isObject(f) || f.type !== 'json_schema' || !isObject(f.schema)) {
      throw new ValidationError('output_config.format must be a json_schema')
    }
    onlyKeys(f, ['type', 'schema'], 'output_config.format')
  }
}

/** ClaudeProvider: the answer request. */
function validateAnswer(body: Json, limits: Limits): ValidRequest {
  onlyKeys(
    body,
    ['model', 'max_tokens', 'stream', 'system', 'output_config', 'cache_control', 'messages', 'fallbacks'],
    'body',
  )

  if (typeof body.model !== 'string' || !limits.allowedModels.has(body.model)) {
    throw new ValidationError(`model "${String(body.model)}" is not allowed`)
  }
  const maxTokens = maxTokensOf(body, limits.maxTokens)
  if (body.stream !== true) throw new ValidationError('stream must be true')
  if (body.system !== undefined && typeof body.system !== 'string') throw new ValidationError('system must be a string')
  if (body.fallbacks !== undefined && body.fallbacks !== 'default') throw new ValidationError('fallbacks must be "default"')
  cacheControl(body.cache_control, 'body')

  outputConfig(body.output_config)

  const messages = body.messages
  if (!Array.isArray(messages) || messages.length === 0 || messages.length > 50) {
    throw new ValidationError('messages must be an array of 1 to 50 messages')
  }
  messages.forEach((m, i) => {
    const where = `messages[${i}]`
    if (!isObject(m)) throw new ValidationError(`${where} must be an object`)
    onlyKeys(m, ['role', 'content'], where)
    if (m.role !== 'user' && m.role !== 'assistant') throw new ValidationError(`${where}.role must be user or assistant`)
    if (typeof m.content === 'string') return
    if (!Array.isArray(m.content) || m.content.length === 0) {
      throw new ValidationError(`${where}.content must be a string or a non-empty array`)
    }
    m.content.forEach((b, j) => block(b, m.role as string, `${where}.content[${j}]`))
  })

  return { model: body.model, maxTokens }
}

/** Beta headers the app may pass through; everything else is dropped. */
export const allowedBetas = new Set(['server-side-fallback-2026-07-01'])

export function filterBetas(header: string | undefined): string | undefined {
  const kept = (header ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter((b) => allowedBetas.has(b))
  return kept.length ? kept.join(',') : undefined
}
