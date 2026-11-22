import { createServer, type IncomingMessage, type Server, type ServerResponse } from 'node:http'
import { authenticate } from './auth.ts'
import type { Config } from './config.ts'
import { RateLimiter, Store } from './store.ts'
import { costUSD, UsageTap } from './usage.ts'
import { filterBetas, validate, ValidationError } from './validate.ts'

// The app's ClaudeProvider talks to this server exactly as it would to api.anthropic.com (same path, body and
// SSE stream), with an app token instead of the API key. Requests are checked, forwarded with the real key, and
// the upstream stream is piped back byte for byte while its usage is recorded.
//
// Raw fetch rather than the Anthropic SDK: this is a transparent pass-through, and the client parses the
// Anthropic wire format itself, so re-serialising SDK events would only add a way to drift.

/** Error in Anthropic's shape, so the app's existing error handling shows it. */
function sendError(res: ServerResponse, status: number, type: string, message: string, headers: Record<string, string> = {}): void {
  if (res.headersSent) return void res.end()
  res.writeHead(status, { 'content-type': 'application/json', ...headers })
  res.end(JSON.stringify({ type: 'error', error: { type, message } }))
}

class TooLarge extends Error {}

async function readBody(req: IncomingMessage, max: number): Promise<Buffer> {
  const declared = Number(req.headers['content-length'] ?? 0)
  if (declared > max) throw new TooLarge()
  const chunks: Buffer[] = []
  let size = 0
  for await (const chunk of req as AsyncIterable<Buffer>) {
    size += chunk.length
    if (size > max) throw new TooLarge()
    chunks.push(chunk)
  }
  return Buffer.concat(chunks)
}

const log = (fields: Record<string, unknown>): void => console.log(JSON.stringify({ ts: new Date().toISOString(), ...fields }))

export function createApp(config: Config, store: Store, limiter = new RateLimiter(config.requestsPerMinute)): Server {
  async function messages(req: IncomingMessage, res: ServerResponse): Promise<void> {
    const started = Date.now()
    const client = authenticate(req.headers.authorization, config.tokens)
    if (!client) return sendError(res, 401, 'authentication_error', 'Missing or unknown app token')

    const wait = limiter.take(client)
    if (wait > 0) {
      return sendError(res, 429, 'rate_limit_error', 'Too many requests, try again shortly', { 'retry-after': String(wait) })
    }
    if (store.spentToday(client) >= config.dailyLimitPerClient || store.spentToday() >= config.dailyLimitTotal) {
      log({ event: 'daily_limit', client })
      return sendError(res, 429, 'rate_limit_error', "Today's usage limit is reached, try again tomorrow")
    }

    let body: Buffer
    let model: string
    try {
      body = await readBody(req, config.maxBodyBytes)
      ;({ model } = validate(JSON.parse(body.toString('utf8')), config))
    } catch (e) {
      if (e instanceof TooLarge) return sendError(res, 413, 'request_too_large', 'Request is too large')
      const message = e instanceof ValidationError ? e.message : 'Body is not valid JSON'
      log({ event: 'rejected', client, reason: message })
      return sendError(res, 400, 'invalid_request_error', message)
    }

    // Stop the upstream request (and its billing) when the app hangs up, e.g. the user asked something else.
    const abort = new AbortController()
    res.on('close', () => abort.abort())

    const headers: Record<string, string> = {
      'content-type': 'application/json',
      'x-api-key': config.anthropicApiKey,
      'anthropic-version': config.anthropicVersion,
    }
    const betas = filterBetas(req.headers['anthropic-beta'] as string | undefined)
    if (betas) headers['anthropic-beta'] = betas

    let upstream: Response
    try {
      upstream = await fetch(`${config.anthropicBaseURL}/v1/messages`, { method: 'POST', headers, body: new Uint8Array(body), signal: abort.signal })
    } catch (e) {
      if (abort.signal.aborted) return
      log({ event: 'upstream_error', client, error: String(e) })
      return sendError(res, 502, 'api_error', 'Could not reach the model provider')
    }

    const requestId = upstream.headers.get('request-id') ?? undefined
    const passHeaders: Record<string, string> = {
      'content-type': upstream.headers.get('content-type') ?? 'application/json',
      'cache-control': 'no-cache',
      // Tells nginx not to buffer, so tokens reach the phone as they arrive.
      'x-accel-buffering': 'no',
    }
    for (const h of ['request-id', 'retry-after']) {
      const v = upstream.headers.get(h)
      if (v) passHeaders[h] = v
    }
    res.writeHead(upstream.status, passHeaders)

    const tap = new UsageTap()
    let completed = false
    try {
      if (upstream.body) {
        for await (const chunk of upstream.body) {
          if (upstream.ok) tap.push(chunk)
          if (!res.write(chunk)) await new Promise((resolve) => res.once('drain', resolve))
        }
      }
      completed = true
    } catch (e) {
      if (!abort.signal.aborted) log({ event: 'stream_error', client, requestId, error: String(e) })
    } finally {
      res.end()
      const usage = tap.usage
      usage.model ??= model
      const cost = costUSD(usage)
      const durationMs = Date.now() - started
      store.record({ client, status: upstream.status, durationMs, requestId, usage, costUSD: cost })
      // An aborted stream only has the usage seen so far, so its cost is a lower bound.
      log({ event: 'request', client, status: upstream.status, completed, durationMs, requestId, costUSD: cost, ...usage })
    }
  }

  return createServer((req, res) => {
    const path = (req.url ?? '/').split('?')[0]
    if (req.method === 'GET' && path === '/health') {
      res.writeHead(200, { 'content-type': 'text/plain' })
      return void res.end('ok')
    }
    if (req.method === 'POST' && path === '/v1/messages') {
      messages(req, res).catch((e: unknown) => {
        log({ event: 'internal_error', error: String(e) })
        sendError(res, 500, 'api_error', 'Internal error')
      })
      return
    }
    sendError(res, 404, 'not_found_error', 'Not found')
  })
}
