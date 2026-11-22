import { join, resolve } from 'node:path'
import { loadConfig } from './config.ts'
import { createApp } from './server.ts'
import { Store } from './store.ts'

const config = loadConfig()
const store = new Store(join(resolve(config.dataFolder), 'ackshually.db'))
const server = createApp(config, store)

// Answers stream for up to ~2 minutes; don't cut them off.
server.requestTimeout = 0
server.listen(config.port, config.host, () => {
  console.log(`ackshually server on http://${config.host}:${config.port} (${config.tokens.size} app token(s))`)
})

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.on(signal, () => {
    server.close(() => {
      store.close()
      process.exit(0)
    })
    // In-flight streams get a few seconds to finish.
    setTimeout(() => process.exit(0), 5000).unref()
  })
}
