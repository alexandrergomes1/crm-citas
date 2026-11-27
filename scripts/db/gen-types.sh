#!/usr/bin/env bash
# Regera src/data/database.generated.ts a partir das migrations do repositório (sem Docker).
# Aplica as migrations num Postgres local (mesmo caminho do `pnpm db:verify`, sem os testes) e lê o esquema `public`
# com o postgres-meta (o mesmo gerador do `supabase gen types`).
# Uso: PGHOST=localhost PGUSER=postgres PGPASSWORD=... pnpm db:types
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DB_NAME="${DB_NAME:-ka_types}"
: "${PGHOST:?defina PGHOST}"; : "${PGUSER:?defina PGUSER}"; : "${PGPASSWORD:?defina PGPASSWORD}"
# Recria o banco do zero: só num banco de tipos e só em máquina local.
case "$DB_NAME" in ka_types*) ;; *) echo "DB_NAME precisa começar com ka_types (recebido: $DB_NAME)"; exit 1;; esac
case "$PGHOST" in localhost|127.0.0.1|::1) ;; *) echo "PGHOST precisa ser local (recebido: $PGHOST)"; exit 1;; esac
PSQL=(psql -X -v ON_ERROR_STOP=1 -q)
"${PSQL[@]}" -d postgres -c "drop database if exists ${DB_NAME} with (force);" -c "create database ${DB_NAME};"
"${PSQL[@]}" -d "$DB_NAME" -f "$ROOT/supabase/tests/00_supabase_stub.sql" >/dev/null
mapfile -t ordered < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$ROOT/scripts/db/migration-order.txt" | grep -v '^!' | grep -v '^$')
mapfile -t ignored < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$ROOT/scripts/db/migration-order.txt" | grep '^!' | cut -c2-)
files=("${ordered[@]}")
for path in $(ls "$ROOT/supabase/migrations"/*.sql | sort); do
  name="$(basename "$path")"
  printf '%s\n' "${ordered[@]}" "${ignored[@]}" | grep -qxF "$name" || files+=("$name")
done
for name in "${files[@]}"; do "${PSQL[@]}" -d "$DB_NAME" -f "$ROOT/supabase/migrations/$name" >/dev/null; done
OUT="$ROOT/src/data/database.generated.ts"
META="$(mktemp -d)"
(cd "$META" && npm init -y >/dev/null && npm i --silent @supabase/postgres-meta@0.100.0 >/dev/null 2>&1)
{
  echo '/* Gerado por `pnpm db:types` a partir das migrations (banco local do replay). NÃO EDITAR. */'
  PG_META_GENERATE_TYPES=typescript PG_META_GENERATE_TYPES_INCLUDED_SCHEMAS=public \
    PG_META_DB_URL="postgresql://${PGUSER}:${PGPASSWORD}@${PGHOST}:${PGPORT:-5432}/${DB_NAME}" \
    node "$META/node_modules/@supabase/postgres-meta/dist/server/server.js" 2>/dev/null
} > "$OUT.tmp"
mv "$OUT.tmp" "$OUT"
