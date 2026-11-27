#!/usr/bin/env bash
# Aplica as migrations, na ordem de produção, num banco Supabase JÁ EXISTENTE (ex.: `supabase start`
# na CI do E2E). Diferente de replay-migrations.sh: não cria banco, não usa o stub e não roda os
# testes de banco. Uso: DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
#   scripts/db/apply-migrations.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ORDER_FILE="$ROOT/scripts/db/migration-order.txt"
: "${DATABASE_URL:?defina DATABASE_URL}"
PSQL=(psql -X -v ON_ERROR_STOP=1 -q "$DATABASE_URL")

mapfile -t ordered < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$ORDER_FILE" | grep -v '^!' | grep -v '^$')
mapfile -t ignored < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$ORDER_FILE" | grep '^!' | cut -c2-)
files=("${ordered[@]}")
for path in $(ls "$ROOT/supabase/migrations"/*.sql | sort); do
  name="$(basename "$path")"
  printf '%s\n' "${ordered[@]}" "${ignored[@]}" | grep -qxF "$name" || files+=("$name")
done

count=0
for name in "${files[@]}"; do
  if ! out=$("${PSQL[@]}" -f "$ROOT/supabase/migrations/$name" 2>&1 >/dev/null); then
    echo "FALHOU: $name"
    echo "$out" | head -20
    exit 1
  fi
  count=$((count + 1))
done
echo "$count migrations aplicadas"
