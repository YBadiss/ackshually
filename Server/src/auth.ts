import { createHash, randomBytes, timingSafeEqual } from 'node:crypto'

export const hashToken = (token: string): string => createHash('sha256').update(token).digest('hex')

export const newToken = (): string => `ack_${randomBytes(32).toString('base64url')}`

/** Client name for a valid `Authorization: Bearer <token>` header, else undefined. Only hashes are stored. */
export function authenticate(header: string | undefined, tokens: Map<string, string>): string | undefined {
  const match = header?.match(/^Bearer\s+(\S+)$/i)
  if (!match?.[1]) return undefined
  const hash = Buffer.from(hashToken(match[1]), 'hex')
  for (const [known, name] of tokens) {
    if (timingSafeEqual(hash, Buffer.from(known, 'hex'))) return name
  }
  return undefined
}
