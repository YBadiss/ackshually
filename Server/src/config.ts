// All settings come from the environment (see .env.example). Parsed once at startup so a bad value fails the
// deploy's health check instead of the first request.

export interface Config {
  port: number
  host: string
  anthropicApiKey: string
  anthropicBaseURL: string
  anthropicVersion: string
  /** sha256 hex of each app token → client name (logged and used for per-client limits). */
  tokens: Map<string, string>
  allowedModels: Set<string>
  maxTokens: number
  maxBodyBytes: number
  /** Daily spend caps in USD (UTC day). The per-client cap applies to each token separately. */
  dailyLimitPerClient: number
  dailyLimitTotal: number
  requestsPerMinute: number
  dataFolder: string
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const required = (name: string): string => {
    const v = env[name]?.trim()
    if (!v) throw new Error(`${name} is not set`)
    return v
  }
  const number = (name: string, fallback: number): number => {
    const raw = env[name]?.trim()
    if (!raw) return fallback
    const n = Number(raw)
    if (!Number.isFinite(n) || n < 0) throw new Error(`${name}=${raw} is not a non-negative number`)
    return n
  }
  const list = (raw: string): string[] =>
    raw
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean)

  const tokens = new Map<string, string>()
  for (const entry of list(required('APP_TOKENS'))) {
    const [name, hash] = entry.split(':')
    if (!name || !hash || !/^[0-9a-f]{64}$/.test(hash)) {
      throw new Error(`APP_TOKENS entry "${entry}" must be <name>:<sha256 hex> (create one with npm run token)`)
    }
    tokens.set(hash, name)
  }

  return {
    port: number('PORT', 3002),
    host: env.HOST?.trim() || '127.0.0.1',
    anthropicApiKey: required('ANTHROPIC_API_KEY'),
    anthropicBaseURL: (env.ANTHROPIC_BASE_URL?.trim() || 'https://api.anthropic.com').replace(/\/+$/, ''),
    anthropicVersion: env.ANTHROPIC_VERSION?.trim() || '2026-10-21',
    tokens,
    allowedModels: new Set(list(env.ALLOWED_MODELS ?? 'claude-sonnet-5-5,claude-opus-5-5')),
    maxTokens: number('MAX_TOKENS', 16000),
    // Anthropic's request limit is 32 MB; a base64 PDF is ~4/3 of the file.
    maxBodyBytes: number('MAX_BODY_MB', 32) * 1024 * 1024,
    dailyLimitPerClient: number('DAILY_LIMIT_USD_PER_CLIENT', 5),
    dailyLimitTotal: number('DAILY_LIMIT_USD_TOTAL', 20),
    requestsPerMinute: number('REQUESTS_PER_MINUTE', 10),
    dataFolder: env.DATA_FOLDER?.trim() || './data',
  }
}
