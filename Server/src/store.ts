import { mkdirSync } from 'node:fs'
import { join } from 'node:path'
import { DatabaseSync } from 'node:sqlite'
import type { Usage } from './usage.ts'

export interface RequestRecord {
  client: string
  status: number
  durationMs: number
  requestId?: string
  usage: Usage
  costUSD: number
}

/** One row per forwarded request (no prompt or answer content), and daily spend sums for the caps. */
export class Store {
  private readonly db: DatabaseSync

  constructor(path: string) {
    if (path !== ':memory:') mkdirSync(join(path, '..'), { recursive: true })
    this.db = new DatabaseSync(path)
    this.db.exec(`
      PRAGMA journal_mode = WAL;
      CREATE TABLE IF NOT EXISTS requests (
        id INTEGER PRIMARY KEY,
        ts TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        day TEXT NOT NULL DEFAULT (date('now')),
        client TEXT NOT NULL,
        status INTEGER NOT NULL,
        duration_ms INTEGER NOT NULL,
        request_id TEXT,
        model TEXT,
        input_tokens INTEGER NOT NULL,
        output_tokens INTEGER NOT NULL,
        cache_write_5m_tokens INTEGER NOT NULL,
        cache_write_1h_tokens INTEGER NOT NULL,
        cache_read_tokens INTEGER NOT NULL,
        cost_usd REAL NOT NULL
      );
      CREATE INDEX IF NOT EXISTS requests_day_client ON requests (day, client);
    `)
  }

  record(r: RequestRecord): void {
    this.db
      .prepare(
        `INSERT INTO requests (client, status, duration_ms, request_id, model, input_tokens, output_tokens,
           cache_write_5m_tokens, cache_write_1h_tokens, cache_read_tokens, cost_usd)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(
        r.client,
        r.status,
        r.durationMs,
        r.requestId ?? null,
        r.usage.model ?? null,
        r.usage.inputTokens,
        r.usage.outputTokens,
        r.usage.cacheWrite5mTokens,
        r.usage.cacheWrite1hTokens,
        r.usage.cacheReadTokens,
        r.costUSD,
      )
  }

  /** Today's (UTC) spend, for one client or for everyone. */
  spentToday(client?: string): number {
    const row = client
      ? this.db.prepare(`SELECT COALESCE(SUM(cost_usd), 0) AS s FROM requests WHERE day = date('now') AND client = ?`).get(client)
      : this.db.prepare(`SELECT COALESCE(SUM(cost_usd), 0) AS s FROM requests WHERE day = date('now')`).get()
    return Number((row as { s: number } | undefined)?.s ?? 0)
  }

  close(): void {
    this.db.close()
  }
}

/** Fixed one-minute windows per client, in memory (resets on restart, which is fine for a burst limit). */
export class RateLimiter {
  private readonly windows = new Map<string, { start: number; count: number }>()
  private readonly perMinute: number
  private readonly now: () => number

  constructor(perMinute: number, now: () => number = Date.now) {
    this.perMinute = perMinute
    this.now = now
  }

  /** Seconds to wait if the client is over the limit, else 0 (and the request is counted). */
  take(client: string): number {
    const t = this.now()
    const w = this.windows.get(client)
    if (!w || t - w.start >= 60_000) {
      this.windows.set(client, { start: t, count: 1 })
      return 0
    }
    if (w.count >= this.perMinute) return Math.ceil((w.start + 60_000 - t) / 1000)
    w.count += 1
    return 0
  }
}
