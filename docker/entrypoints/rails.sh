#!/bin/sh
set -eu

APP_DIR="/app"

# Limpeza
rm -f "${APP_DIR}/tmp/pids/server.pid"
rm -rf "${APP_DIR}/tmp/cache/"*

# Defaults
: "${POSTGRES_HOST:=localhost}"
: "${POSTGRES_PORT:=5432}"
: "${POSTGRES_USERNAME:=postgres}"
: "${POSTGRES_DATABASE:=postgres}"

echo "Waiting for postgres to become ready..."
until pg_isready -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USERNAME" >/dev/null 2>&1; do
  echo "  -> Ainda iniciando em $POSTGRES_HOST:$POSTGRES_PORT ..."
  sleep 2
done
echo "Postgres is ready."

# Migrations idempotentes
if bundle exec rake -T | grep -q "db:chatwoot_prepare"; then
  echo "Running db:chatwoot_prepare..."
  bundle exec rails db:chatwoot_prepare
else
  echo "Running rails db:prepare..."
  bundle exec rails db:prepare
fi

echo "Starting process: $*"
exec "$@"
