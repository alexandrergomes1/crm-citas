#!/usr/bin/env bash
# Sobe o Supabase local, aplica as migrations e semeia o estúdio do E2E. Só para a CI/local.
# Saída: linhas KEY=VALUE em $GITHUB_ENV (ou no arquivo passado em E2E_ENV_FILE).
set -Eeuo pipefail
LOG="$(mktemp)"
# Falha vira anotação no PR (o log bruto da CI nem sempre está acessível).
report() {
  local msg; msg="$(tail -c 3000 "$LOG" | sed ':a;N;$!ba;s/%/%25/g;s/\r/%0D/g;s/\n/%0A/g')"
  echo "::error title=E2E setup (passo: ${STEP:-?})::${msg}"
}
trap report ERR
run() { "$@" >>"$LOG" 2>&1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${E2E_ENV_FILE:-${GITHUB_ENV:-/dev/stdout}}"
WORK="$(mktemp -d)"

# Projeto vazio: as migrations do repositório são aplicadas pela lista de ordem de produção.
STEP=init; (cd "$WORK" && run supabase init --force)
# Validade do link de e-mail (recuperação / criar senha) fixa em 1 hora, como em produção (docs/STATUS.md).
STEP=config; grep -q '^otp_expiry' "$WORK/supabase/config.toml" && sed -i 's/^otp_expiry = .*/otp_expiry = 3600/' "$WORK/supabase/config.toml"
STEP=start; (cd "$WORK" && run supabase start -x studio,imgproxy,inbucket,edge-runtime,logflare,vector,realtime,supavisor,postgres-meta)
STEP=status; (cd "$WORK" && supabase status -o env) > "$WORK/status.env" 2>>"$LOG"
sed -n 's/^\([A-Z_]*\)=/export SB_\1=/p' "$WORK/status.env" > "$WORK/status.sh"
# shellcheck disable=SC1091
. "$WORK/status.sh"
echo "chaves do status: $(cut -d= -f1 "$WORK/status.env" | tr '\n' ' ')" >>"$LOG"

export DATABASE_URL="$SB_DB_URL"
STEP=shims; run psql -X -v ON_ERROR_STOP=1 -q "$DATABASE_URL" -f "$ROOT/e2e/ci/platform-shims.sql"
STEP=migrations; run bash "$ROOT/scripts/db/apply-migrations.sh"
# Ajuda de limpeza só do E2E (apaga cliente de teste, inclusive com ficha assinada): fora das migrations.
STEP=helpers; run psql -X -v ON_ERROR_STOP=1 -q "$DATABASE_URL" -f "$ROOT/e2e/ci/test-helpers.sql"

# Senhas aleatórias de teste, só desta execução.
OWNER_PASSWORD="E2e-$(openssl rand -hex 12)"
RECEP_PASSWORD="E2e-$(openssl rand -hex 12)"
echo "::add-mask::$OWNER_PASSWORD"; echo "::add-mask::$RECEP_PASSWORD"
create_user() {
  curl -sS -f -X POST "$SB_API_URL/auth/v1/admin/users" \
    -H "apikey: $SB_SERVICE_ROLE_KEY" -H "Authorization: Bearer $SB_SERVICE_ROLE_KEY" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"$2\",\"email_confirm\":true}" | jq -r .id
}
STEP=usuarias
OWNER_ID="$(create_user owner@e2e.test "$OWNER_PASSWORD")"
RECEP_ID="$(create_user recepcao@e2e.test "$RECEP_PASSWORD")"

STEP=seed
APPT_LINE="$(psql -X -q "$DATABASE_URL" -v owner_id="$OWNER_ID" -v recep_id="$RECEP_ID" -f "$ROOT/e2e/ci/seed.sql" | grep '^E2E_')"

# Mundo dos mockups V25 no mesmo estúdio (clientes, agenda, comandas, fichas) para as capturas logadas.
STEP=seed-v25
run psql -X -v ON_ERROR_STOP=1 -q "$DATABASE_URL" -v org_id=0e2e0000-0000-4000-8000-000000000001 -v owner_id="$OWNER_ID" \
  -f "$ROOT/supabase/seed/02_v25_dados_teste.sql"

{
  echo "NEXT_PUBLIC_SUPABASE_URL=$SB_API_URL"
  echo "NEXT_PUBLIC_SUPABASE_ANON_KEY=$SB_ANON_KEY"
  echo "SUPABASE_SERVICE_ROLE_KEY=$SB_SERVICE_ROLE_KEY"
  echo "E2E_ORG_SLUG=e2e-studio"
  echo "E2E_EMAIL=owner@e2e.test"
  echo "E2E_PASSWORD=$OWNER_PASSWORD"
  echo "E2E_RECEP_EMAIL=recepcao@e2e.test"
  echo "E2E_RECEP_PASSWORD=$RECEP_PASSWORD"
  echo "$APPT_LINE"
} >> "$OUT"
echo "Supabase local pronto e estúdio do E2E semeado."
