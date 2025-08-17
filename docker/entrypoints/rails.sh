#!/bin/sh
set -euo pipefail

# Limpeza de artefatos
rm -f /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

echo "Waiting for postgres to become ready..."
$(docker/entrypoints/helpers/pg_database_url.rb) >/dev/null 2>&1 || true
PG_READY="pg_isready -h ${POSTGRES_HOST:-localhost} -p ${POSTGRES_PORT:-5432} -U ${POSTGRES_USERNAME:-postgres}"

until $PG_READY >/dev/null 2>&1; do
  sleep 2
done
echo "Postgres is ready."

# NÃO instale gems em runtime em produção. Garantimos no build.
# bundle install  # <- remova

# Executa migrations + seeds idempotentes
if bundle exec rake -T | grep -q "db:chatwoot_prepare"; then
  echo "Running db:chatwoot_prepare..."
  bundle exec rails db:chatwoot_prepare
else
  echo "Running rails db:prepare..."
  bundle exec rails db:prepare
fi

echo "Starting process: $*"
exec "$@"
