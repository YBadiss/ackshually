# Server

Keeps the Anthropic API key off the phone. The app's `ClaudeProvider` (Core) sends the same streamed
`POST /v1/messages` it would send to Anthropic, with `Authorization: Bearer <app token>` instead of the key. The
server:

1. checks the token (only sha256 hashes are stored) and a per-client rate limit and daily spend cap,
2. checks the body against an allowlist of the shape Core sends ([`src/validate.ts`](src/validate.ts)): allowed
   models, `max_tokens` cap, `stream: true`, text and PDF blocks only, no tools, so a leaked token isn't a
   general-purpose Claude relay,
3. forwards it with the real key and pins `anthropic-version`,
4. pipes the SSE stream back byte for byte, reading usage from `message_start` / `message_delta` on the way, and
   logs one row per request (tokens, cost, duration; never prompts or answers) to SQLite.

Errors come back in Anthropic's error shape, so the app shows them the same way. Retrieval (page selection) stays on
the device, so the server needs no rulebooks.

Node 24 runs the TypeScript directly (type stripping) and there are no runtime dependencies, so there is no build
step and nothing to install on the server.

## Run locally

```sh
cd Server
npm install                       # dev tools only (TypeScript, Node types)
cp .env.example .env              # set ANTHROPIC_API_KEY
npm run token -- my-laptop        # prints a token and the APP_TOKENS entry to put in .env
npm run dev                       # http://127.0.0.1:3002
npm test                          # against a fake upstream, no key needed
npm run typecheck
```

Bench through it, as the app would (the judge still calls Anthropic directly):

```sh
cd evals
ACKSHUALLY_APP_TOKEN=ack_... swift run bench run --questions questions/fixture.json --base-url http://127.0.0.1:3002
```

When Core starts sending a new request field, add it to `src/validate.ts` (and its test). Core's
`testRequestFieldsAreAllowedByServer` fails first as a reminder.

## Deploy

Same setup as the other services on the droplet: PM2 behind nginx, deployed by GitHub Actions over SSH.

- Pushing `Server/**` to `main` runs [`deploy-server.yml`](../.github/workflows/deploy-server.yml): typecheck and
  tests, then [`scripts/deploy.sh`](scripts/deploy.sh) copies `src/` to `/var/www/ackshually/server-<timestamp>`,
  links the env file, restarts `ackshually-server` under PM2 on port 3002, health-checks it and keeps 3 deploys.
- Pushing `Server/nginx/**` runs [`deploy-server-nginx.yml`](../.github/workflows/deploy-server-nginx.yml): uploads
  [`nginx/nginx-config`](nginx/nginx-config), tests it (rolling back on failure) and reloads nginx.

Secrets: `/home/deploy/secrets/ackshually-server.env` on the droplet (see [`.env.example`](.env.example)). The
request log and daily spend live in `/var/www/ackshually/data/ackshually.db`.

### First deploy (once, by hand)

1. DNS: an `A` record `ackshually.badyass.xyz` → the droplet.
2. GitHub repo settings: secrets `SSH_DEPLOY_KEY` and `SSH_KNOWN_HOSTS`, variables `DEPLOY_HOST` and `DEPLOY_USER`
   (`deploy`), same values as recip.it.
3. On the droplet, as `admin`:
   ```sh
   # Env file (fill in the key and the APP_TOKENS from `npm run token -- <device>`)
   sudo -u deploy install -m 600 /dev/null /home/deploy/secrets/ackshually-server.env
   sudo -u deploy nano /home/deploy/secrets/ackshually-server.env
   # Certificate, then an empty vhost owned by deploy so CI can update it
   sudo certbot certonly --nginx -d ackshually.badyass.xyz
   sudo install -m 644 -o deploy -g deploy /dev/null /etc/nginx/sites-available/ackshually
   sudo ln -s /etc/nginx/sites-available/ackshually /etc/nginx/sites-enabled/ackshually
   ```
4. Run the two workflows (Actions → Run workflow): **Server nginx**, then **Server**.
5. Check: `curl https://ackshually.badyass.xyz/health` → `ok`.

Add or revoke a device by editing `APP_TOKENS` in the env file and running `pm2 restart ackshually-server --update-env`
(or re-running the Server workflow).

### Usage

```sh
sqlite3 /var/www/ackshually/data/ackshually.db \
  "SELECT day, client, COUNT(*), ROUND(SUM(cost_usd), 3) FROM requests GROUP BY day, client ORDER BY day DESC LIMIT 20"
```

## The app's token

The app sends `Authorization: Bearer <token>` to `https://ackshually.badyass.xyz` by default. The token is **built into
the app**: `App/Config/Base.xcconfig` includes the git-ignored `App/Config/Secrets.xcconfig` (copy
`Secrets.example.xcconfig`, paste a token from `npm run token -- <name>`), which feeds `ACKSHUALLY_APP_TOKEN` into
Info.plist, where `ServerConfig` reads it. Without the file the app still builds; it then needs a token override or an
API key in Settings → Developer.

**Risk:** a bundled token is readable by anyone who has the app binary (it sits in Info.plist). That's acceptable for
our own devices and TestFlight, not for a public release (App Attest, below). Revoking it means removing its hash
from `APP_TOKENS`, generating a new one, and rebuilding the app with it; every install of the old build stops working.

The app relies on the error shapes above: 401 → "check your access token in Settings"; 429 **with** `retry-after` →
"try again in N seconds"; 429 **without** it → "today's limit is reached, try again tomorrow". Keep the daily cap free
of `retry-after`, or the app shows the wrong message.

## Not yet

- **App Attest** before a public release: today the token is a shared secret bundled with the build, fine for our own
  phones and TestFlight but extractable from a public build. With App Attest the app gets a short-lived token only after Apple vouches for it.
