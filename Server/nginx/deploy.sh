#!/bin/bash
# Uploads nginx-config to the droplet, tests it (rolling back on failure) and reloads nginx.
# The vhost file is owned by deploy (like the other sites), but creating it and the certificate needs root once:
# see "First deploy" in Server/README.md.
set -euo pipefail
cd "$(dirname "$0")"

SERVER="${DEPLOY_USER:-deploy}@${DEPLOY_HOST:-167.71.143.97}"
REMOTE=/etc/nginx/sites-available/ackshually
backup="nginx-config-$(date +%s).bak"

scp "$SERVER:$REMOTE" "$backup"
scp nginx-config "$SERVER:$REMOTE"

if ! ssh "$SERVER" "sudo -n nginx -t"; then
    echo "nginx config test failed, rolling back to the previous config." >&2
    scp "$backup" "$SERVER:$REMOTE"
    exit 1
fi

ssh "$SERVER" "sudo -n systemctl reload nginx"
