import assert from 'node:assert/strict'
import { createServer, type Server } from 'node:http'
import type { AddressInfo } from 'node:net'
import { after, before, beforeEach, describe, it } from 'node:test'
import { hashToken } from '../src/auth.ts'
import { loadConfig, type Config } from '../src/config.ts'
import { createApp } from '../src/server.ts'
import { RateLimiter, Store } from '../src/store.ts'
import { costUSD, emptyUsage, UsageTap } from '../src/usage.ts'
import { validate, ValidationError } from '../src/validate.ts'

const TOKEN = 'ack_test-token'

/** The body ClaudeProvider sends (json mode, excerpt as text, one follow-up). */
const coreBody = (): { messages: { role: string; content: string | Record<string, unknown>[] }[]; [k: string]: unknown } => ({
  model: 'claude-sonnet-5-5',
  max_tokens: 16000,
  stream: true,
  system: 'You answer board game rules questions…',
  output_config: { effort: 'low', format: { type: 'json_schema', schema: { type: 'object' } } },
  cache_control: { type: 'ephemeral', ttl: '1h' },
  fallbacks: 'default',
  messages: [
    {
      role: 'user',
      content: [
        { type: 'document', source: { type: 'base64', media_type: 'application/pdf', data: 'JVBERi0=' }, title: 'Azul', cache_control: { type: 'ephemeral', ttl: '1h' } },
        { type: 'text', text: 'Can I take tiles from the centre?' },
      ],
    },
    { role: 'assistant', content: '{"verdict":"yes"}' },
    { role: 'user', content: 'And the first player marker?' },
  ],
})

const sse = (events: object[]) => events.map((e) => `event: ${(e as { type: string }).type}\ndata: ${JSON.stringify(e)}\n\n`).join('')

const upstreamStream = sse([
  {
    type: 'message_start',
    message: {
      model: 'claude-sonnet-5-5',
      usage: { input_tokens: 100, cache_read_input_tokens: 0, cache_creation_input_tokens: 50000, cache_creation: { ephemeral_5m_input_tokens: 0, ephemeral_1h_input_tokens: 50000 }, output_tokens: 1 },
    },
  },
  { type: 'content_block_start', index: 0, content_block: { type: 'text', text: '' } },
  { type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text: '{"verdict":' } },
  { type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text: '"yes"}' } },
  { type: 'content_block_stop', index: 0 },
  { type: 'message_delta', delta: { stop_reason: 'end_turn' }, usage: { output_tokens: 400 } },
  { type: 'message_stop' },
])

describe('server', () => {
  let upstream: Server
  let app: Server
  let base: string
  let config: Config
  let store: Store
  let seen: { headers: Record<string, unknown>; body: string }[] = []
  let upstreamStatus = 200

  before(async () => {
    upstream = createServer(async (req, res) => {
      let body = ''
      for await (const c of req) body += c
      seen.push({ headers: req.headers, body })
      if (upstreamStatus !== 200) {
        res.writeHead(upstreamStatus, { 'content-type': 'application/json', 'request-id': 'req_err' })
        return void res.end(JSON.stringify({ type: 'error', error: { type: 'overloaded_error', message: 'Overloaded' } }))
      }
      res.writeHead(200, { 'content-type': 'text/event-stream', 'request-id': 'req_123' })
      res.end(upstreamStream)
    })
    await new Promise<void>((r) => upstream.listen(0, '127.0.0.1', r))
    const upstreamURL = `http://127.0.0.1:${(upstream.address() as AddressInfo).port}`
    config = loadConfig({
      APP_TOKENS: `test-phone:${hashToken(TOKEN)}`,
      ANTHROPIC_API_KEY: 'sk-ant-real',
      ANTHROPIC_BASE_URL: upstreamURL,
      MAX_BODY_MB: '1',
    })
  })

  beforeEach(async () => {
    seen = []
    upstreamStatus = 200
    store = new Store(':memory:')
    app?.close()
    app = createApp(config, store, new RateLimiter(100))
    await new Promise<void>((r) => app.listen(0, '127.0.0.1', r))
    base = `http://127.0.0.1:${(app.address() as AddressInfo).port}`
  })

  after(() => {
    app.close()
    upstream.close()
  })

  const post = (body: unknown, headers: Record<string, string> = { authorization: `Bearer ${TOKEN}` }) =>
    fetch(`${base}/v1/messages`, { method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: JSON.stringify(body) })

  it('forwards a Core request with the real key and streams the response back unchanged', async () => {
    const res = await post(coreBody(), {
      authorization: `Bearer ${TOKEN}`,
      'anthropic-beta': 'server-side-fallback-2026-07-01, some-other-beta',
      'x-api-key': 'sk-from-client',
    })
    assert.equal(res.status, 200)
    assert.equal(res.headers.get('request-id'), 'req_123')
    assert.equal(await res.text(), upstreamStream)

    assert.equal(seen.length, 1)
    const h = seen[0]!.headers
    assert.equal(h['x-api-key'], 'sk-ant-real')
    assert.equal(h['anthropic-version'], '2026-10-21')
    assert.equal(h['anthropic-beta'], 'server-side-fallback-2026-07-01')
    assert.equal(h.authorization, undefined)
    assert.deepEqual(JSON.parse(seen[0]!.body), coreBody())
  })

  it('records usage and cost', async () => {
    await (await post(coreBody())).text()
    // 100 input × $2 + 400 output × $10 + 50k 1h cache writes × $4, per million.
    assert.equal(store.spentToday('test-phone').toFixed(4), ((100 * 2 + 400 * 10 + 50000 * 4) / 1e6).toFixed(4))
  })

  it('refuses missing or unknown tokens before calling upstream', async () => {
    assert.equal((await post(coreBody(), {})).status, 401)
    assert.equal((await post(coreBody(), { authorization: 'Bearer nope' })).status, 401)
    assert.equal(seen.length, 0)
  })

  it('refuses requests outside the allowlist', async () => {
    for (const body of [
      { ...coreBody(), model: 'claude-fable-5-2' },
      { ...coreBody(), max_tokens: 64000 },
      { ...coreBody(), stream: false },
      { ...coreBody(), tools: [{ type: 'web_search_20260209', name: 'web_search' }] },
      { ...coreBody(), messages: [{ role: 'user', content: [{ type: 'image', source: {} }] }] },
    ]) {
      const res = await post(body)
      assert.equal(res.status, 400, JSON.stringify(body).slice(0, 80))
      const err = (await res.json()) as { type: string; error: { type: string } }
      assert.equal(err.error.type, 'invalid_request_error')
    }
    assert.equal(seen.length, 0)
  })

  it('refuses bodies over the size limit', async () => {
    const big = coreBody()
    ;((big.messages[0]!.content as Record<string, unknown>[])[0]!.source as { data: string }).data = 'A'.repeat(2 * 1024 * 1024)
    assert.equal((await post(big)).status, 413)
  })

  it('passes upstream errors through', async () => {
    upstreamStatus = 529
    const res = await post(coreBody())
    assert.equal(res.status, 529)
    assert.equal(((await res.json()) as { error: { type: string } }).error.type, 'overloaded_error')
  })

  it('stops at the daily limit', async () => {
    const limited = createApp({ ...config, dailyLimitPerClient: 0.1 }, store, new RateLimiter(100))
    await new Promise<void>((r) => limited.listen(0, '127.0.0.1', r))
    const url = `http://127.0.0.1:${(limited.address() as AddressInfo).port}/v1/messages`
    const send = () => fetch(url, { method: 'POST', headers: { authorization: `Bearer ${TOKEN}` }, body: JSON.stringify(coreBody()) })
    assert.equal((await send()).status, 200) // first one is under the cap; costs ~$0.2
    await new Promise((r) => setTimeout(r, 50))
    assert.equal((await send()).status, 429)
    limited.close()
  })

  it('answers health checks without a token', async () => {
    const res = await fetch(`${base}/health`)
    assert.equal(res.status, 200)
  })
})

describe('rate limiter', () => {
  it('allows N per minute per client', () => {
    let t = 0
    const rl = new RateLimiter(2, () => t)
    assert.equal(rl.take('a'), 0)
    assert.equal(rl.take('a'), 0)
    assert.ok(rl.take('a') > 0)
    assert.equal(rl.take('b'), 0)
    t = 60_000
    assert.equal(rl.take('a'), 0)
  })
})

describe('usage', () => {
  it('reads usage across chunk boundaries', () => {
    const tap = new UsageTap()
    const bytes = new TextEncoder().encode(upstreamStream)
    for (let i = 0; i < bytes.length; i += 7) tap.push(bytes.slice(i, i + 7))
    assert.deepEqual(tap.usage, { ...emptyUsage(), model: 'claude-sonnet-5-5', inputTokens: 100, outputTokens: 400, cacheWrite1hTokens: 50000 })
  })

  it('prices cache reads and unknown models', () => {
    assert.equal(costUSD({ ...emptyUsage(), model: 'claude-sonnet-5-5', cacheReadTokens: 1_000_000 }), 0.1)
    assert.equal(costUSD({ ...emptyUsage(), model: 'claude-new-model', inputTokens: 1_000_000 }), 4)
  })
})

describe('validate', () => {
  const limits = { allowedModels: new Set(['claude-sonnet-5-5']), maxTokens: 16000 }
  it('accepts the Core body, including citations mode', () => {
    assert.deepEqual(validate(coreBody(), limits), { model: 'claude-sonnet-5-5', maxTokens: 16000 })
    const citations = coreBody()
    ;(citations.messages[0]!.content as Record<string, unknown>[])[0]!.citations = { enabled: true }
    delete (citations.output_config as { format?: unknown }).format
    validate(citations, limits)
  })
  it('refuses documents in assistant turns', () => {
    const b = coreBody()
    b.messages[1] = { role: 'assistant', content: b.messages[0]!.content }
    assert.throws(() => validate(b, limits), ValidationError)
  })
})
