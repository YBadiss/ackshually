#!/bin/bash
# Uploads the server (no build step: Node 24 runs the TypeScript directly, and there are no runtime dependencies)
# to the droplet and (re)starts it under PM2 from the new directory. Keeps the 3 latest deploys.
set -euo pipefail
cd "$(dirname "$0")/.."

SERVER="${DEPLOY_USER:-deploy}@${DEPLOY_HOST:-167.71.143.97}"
BASE=/var/www/ackshually
ENV_FILE="${ACKSHUALLY_ENV_FILE:-/home/deploy/secrets/ackshually-server.env}"
NAME=ackshually-server
PORT=3002
timestamp=$(date +%s)
DIR="$BASE/server-$timestamp"

# Node >= 24 (type stripping, node:sqlite) and an env file with the secrets; data lives outside deploy directories.
ssh "$SERVER" bash -s -- "$ENV_FILE" <<'CHECK'
set -euo pipefail
env_file=$1
node -e 'if (Number(process.versions.node.split(".")[0]) < 24) { console.error(`Node ${process.version} is too old: need >= 24`); process.exit(1) }'
[ -f "$env_file" ] || { echo "Env file $env_file not found (see Server/.env.example)" >&2; exit 1; }
for v in ANTHROPIC_API_KEY APP_TOKENS; do
  grep -qE "^$v=." "$env_file" || { echo "$v is not set in $env_file" >&2; exit 1; }
done
CHECK

ssh "$SERVER" "mkdir -p $DIR $BASE/data"
scp -rq src package.json "$SERVER:$DIR/"
ssh "$SERVER" "ln -s $ENV_FILE $DIR/.env && ln -sfn $DIR $BASE/server"

# PORT and DATA_FOLDER are set here; node --env-file never overrides variables already in the environment.
ssh "$SERVER" "pm2 delete $NAME >/dev/null 2>&1 || true; cd $DIR && \
  PORT=$PORT DATA_FOLDER=$BASE/data NODE_ENV=production pm2 start src/main.ts --name $NAME --interpreter node \
    --node-args='--env-file=$DIR/.env --disable-warning=ExperimentalWarning' && pm2 save"
ssh "$SERVER" "sleep 2 && pm2 logs $NAME --lines 10 --nostream && curl -fsS -o /dev/null -w 'Health check: HTTP %{http_code}\n' http://127.0.0.1:$PORT/health"

ssh "$SERVER" "cd $BASE && ls -d server-[0-9]* | sort -t- -k2 -n | head -n -3 | xargs -r -t rm -rf --"
