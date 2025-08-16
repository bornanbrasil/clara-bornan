#!/bin/sh
set -eu

APP_DIR="/app"

rm -f "${APP_DIR}/tmp/pids/server.pid"
rm -rf "${APP_DIR}/tmp/cache/"*

pnpm store prune || true
pnpm install --force

echo "Ready to run Vite development server."
exec "$@"
