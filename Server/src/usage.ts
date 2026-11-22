// Reads token usage out of the SSE stream as it passes through, and prices it.

export interface Usage {
  model?: string
  inputTokens: number
  outputTokens: number
  cacheWrite5mTokens: number
  cacheWrite1hTokens: number
  cacheReadTokens: number
}

export const emptyUsage = (): Usage => ({
  inputTokens: 0,
  outputTokens: 0,
  cacheWrite5mTokens: 0,
  cacheWrite1hTokens: 0,
  cacheReadTokens: 0,
})

/** USD per million tokens. Cache writes cost 1.25x input (5 min) or 2x input (1 hour). */
interface Price {
  input: number
  output: number
  cacheRead: number
}

const prices: Record<string, Price> = {
  'claude-sonnet-5-5': { input: 2, output: 10, cacheRead: 0.1 },
  'claude-opus-5-5': { input: 4, output: 20, cacheRead: 0.2 },
  // Server-side refusal fallback target for claude-sonnet-5-5.
  'claude-sonnet-5': { input: 2, output: 10, cacheRead: 0.2 },
}
// Unknown models (e.g. a fallback we haven't listed) are priced like the most expensive known one.
const unknownPrice: Price = { input: 4, output: 20, cacheRead: 0.2 }

export function costUSD(u: Usage): number {
  const p = (u.model && prices[u.model]) || unknownPrice
  const perToken =
    u.inputTokens * p.input +
    u.outputTokens * p.output +
    u.cacheWrite5mTokens * p.input * 1.25 +
    u.cacheWrite1hTokens * p.input * 2 +
    u.cacheReadTokens * p.cacheRead
  return perToken / 1_000_000
}

function merge(u: Usage, raw: unknown): void {
  if (typeof raw !== 'object' || raw === null) return
  const r = raw as Record<string, unknown>
  const n = (k: string): number | undefined => (typeof r[k] === 'number' && (r[k] as number) > 0 ? (r[k] as number) : undefined)
  u.inputTokens = n('input_tokens') ?? u.inputTokens
  // output_tokens in message_delta is cumulative.
  u.outputTokens = n('output_tokens') ?? u.outputTokens
  u.cacheReadTokens = n('cache_read_input_tokens') ?? u.cacheReadTokens
  const creation = r.cache_creation as Record<string, unknown> | undefined
  const fiveMin = typeof creation?.ephemeral_5m_input_tokens === 'number' ? creation.ephemeral_5m_input_tokens : undefined
  const oneHour = typeof creation?.ephemeral_1h_input_tokens === 'number' ? creation.ephemeral_1h_input_tokens : undefined
  if (fiveMin !== undefined || oneHour !== undefined) {
    if (fiveMin) u.cacheWrite5mTokens = fiveMin
    if (oneHour) u.cacheWrite1hTokens = oneHour
  } else {
    // No breakdown: count every cache write at the 1-hour rate (what the app uses, and the higher one).
    const total = n('cache_creation_input_tokens')
    if (total) u.cacheWrite1hTokens = total
  }
}

/** Feed raw SSE bytes; collects the model and usage from message_start / message_delta events. */
export class UsageTap {
  readonly usage = emptyUsage()
  private buffer = ''
  private readonly decoder = new TextDecoder()

  push(chunk: Uint8Array): void {
    this.buffer += this.decoder.decode(chunk, { stream: true })
    let nl: number
    while ((nl = this.buffer.indexOf('\n')) >= 0) {
      const line = this.buffer.slice(0, nl).replace(/\r$/, '')
      this.buffer = this.buffer.slice(nl + 1)
      if (line.startsWith('data:')) this.event(line.slice(5).trim())
    }
  }

  private event(data: string): void {
    // Only these two events carry usage; skip parsing the (much more frequent) deltas.
    if (!data.includes('"message_start"') && !data.includes('"message_delta"')) return
    let obj: Record<string, unknown>
    try {
      obj = JSON.parse(data) as Record<string, unknown>
    } catch {
      return
    }
    if (obj.type === 'message_start') {
      const message = obj.message as Record<string, unknown> | undefined
      if (typeof message?.model === 'string') this.usage.model = message.model
      merge(this.usage, message?.usage)
    } else if (obj.type === 'message_delta') {
      merge(this.usage, obj.usage)
    }
  }
}
