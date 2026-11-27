#!/usr/bin/env bash
# Aplica todas as migrations em ordem num Postgres limpo e roda as checagens de segurança.
# Uso: scripts/db/replay-migrations.sh            (usa PGHOST/PGPORT/PGUSER do ambiente)
#      DB_NAME=ka_replay scripts/db/replay-migrations.sh
# Requer: psql e um Postgres 15+ acessível. Não usa Docker nem o projeto Supabase real.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DB_NAME="${DB_NAME:-ka_replay}"
ORDER_FILE="$ROOT/scripts/db/migration-order.txt"
# SKIP: regex extra de arquivos a pular (ex.: SKIP='/20261028210000_' para ver o banco antes dela).
SKIP="${SKIP:-}"
PSQL=(psql -X -v ON_ERROR_STOP=1 -q)

"${PSQL[@]}" -d postgres -c "drop database if exists ${DB_NAME} with (force);" >/dev/null
"${PSQL[@]}" -d postgres -c "create database ${DB_NAME};" >/dev/null

echo "== stub do Supabase"
"${PSQL[@]}" -d "$DB_NAME" -f "$ROOT/supabase/tests/00_supabase_stub.sql" >/dev/null

echo "== migrations"
# Ordem: a lista de produção primeiro; depois os arquivos novos, por nome.
mapfile -t ordered < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$ORDER_FILE" | grep -v '^!' | grep -v '^$')
mapfile -t ignored < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$ORDER_FILE" | grep '^!' | cut -c2-)
files=()
for name in "${ordered[@]}"; do
  [ -f "$ROOT/supabase/migrations/$name" ] || { echo "Lista cita arquivo inexistente: $name"; exit 1; }
  files+=("$name")
done
for path in $(ls "$ROOT/supabase/migrations"/*.sql | sort); do
  name="$(basename "$path")"
  printf '%s\n' "${ordered[@]}" "${ignored[@]}" | grep -qxF "$name" || files+=("$name")
done

count=0
for name in "${files[@]}"; do
  if [ -n "$SKIP" ] && echo "/$name" | grep -Eq "$SKIP"; then continue; fi
  f="$ROOT/supabase/migrations/$name"
  if ! out=$("${PSQL[@]}" -d "$DB_NAME" -f "$f" 2>&1 >/dev/null); then
    echo "FALHOU: $name"
    echo "$out" | head -20
    exit 1
  fi
  count=$((count + 1))
done
echo "   $count migrations aplicadas"

echo "== checagens de segurança"
"${PSQL[@]}" -d "$DB_NAME" -f "$ROOT/supabase/tests/10_security_checks.sql"

# Testes de comportamento: todo arquivo N..._*.sql com número a partir de 20, inclusive 100+
# (cada um desfaz o que faz). Ordem numérica, não alfabética.
for t in $(ls "$ROOT/supabase/tests"/[0-9]*_*.sql 2>/dev/null | sort -V); do
  num="$(basename "$t" | sed -E 's/^([0-9]+)_.*/\1/')"
  [ "$((10#$num))" -ge 20 ] || continue
  echo "== $(basename "$t" .sql)"
  "${PSQL[@]}" -d "$DB_NAME" -f "$t"
done
echo "OK"
