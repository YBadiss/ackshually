// Prints a new app token and the APP_TOKENS entry for the server's env file.
// Usage: npm run token -- <client-name>   (e.g. yacine-iphone)
import { hashToken, newToken } from '../src/auth.ts'

const name = process.argv[2]
if (!name || !/^[\w.-]+$/.test(name)) {
  console.error('Usage: npm run token -- <client-name>   (letters, digits, . _ -)')
  process.exit(1)
}
const token = newToken()
console.log(`Token (put it in the app, then forget it):\n  ${token}\n`)
console.log(`Add to APP_TOKENS in the server env file (comma-separated):\n  ${name}:${hashToken(token)}`)
