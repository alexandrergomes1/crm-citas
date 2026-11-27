#!/usr/bin/env bash
# Aplica no banco de DESENVOLVIMENTO as migrations que ainda não estão no histórico dele.
# Sem IA. Não usa "supabase db push": o histórico do banco de dev tem versões com o horário em que
# a migration foi aplicada (não o do arquivo), então a comparação é por versão OU por nome.
#
# Entrada (variáveis de ambiente):
#   DB_URL   URL de conexão do banco (obrigatória; nunca é impressa)
#   DRY_RUN  true (padrão) só lista; false aplica
#   DEV_REF  trecho que a URL precisa conter (padrão: ref do projeto de desenvolvimento).
#            Só os testes locais mudam isso; o workflow nunca muda.
#   MIG_DIR  pasta das migrations (padrão: supabase/migrations)
#
# Regras:
#  - Só considera arquivos <14 dígitos>_<nome>.sql. Os arquivos antigos AAAAMMDD_NNN_nome.sql
#    são a fundação anterior ao histórico (ver migration-order.txt) e não são tocados.
#  - Só arquivos com carimbo >= MIN_VERSION (padrão 20261113000000, início do crm-agenda).
#  - Aplicado = versão do arquivo existe no histórico OU o nome existe no histórico.
#  - Cada pendente roda em UMA transação com o registro no histórico. Para no primeiro erro.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MIG_DIR="${MIG_DIR:-$ROOT/supabase/migrations}"
# Corte: migrations anteriores a este carimbo vieram do sistema antigo e já estão no banco de dev,
# muitas registradas com outro nome (histórico bagunçado). Nunca reaplicar.
MIN_VERSION="${MIN_VERSION:-20261113000000}"
DRY_RUN="${DRY_RUN:-true}"
DEV_REF="${DEV_REF:-qjcabltvchmzmpigiyrv}"
PROD_REF="bwpltaufyenmumsfaczb"
URL="${DB_URL:-}"

fail() { echo "ERRO: $*" >&2; exit 1; }
# Nunca imprimir a URL: tudo que vem do psql passa por aqui.
scrub() { local t; t="$(cat)"; printf '%s\n' "${t//"$URL"/<db-url>}"; }

[ -n "$URL" ] || fail "DB_URL vazia (configure o segredo DEV_DB_URL ou SUPABASE_DB_URL)."
case "$URL" in *"$PROD_REF"*) fail "a URL aponta para o banco de PRODUCAO. Abortado." ;; esac
case "$URL" in *"$DEV_REF"*) ;; *) fail "a URL não é a do banco de desenvolvimento (falta o ref esperado). Abortado." ;; esac
case "$DRY_RUN" in true|false) ;; *) fail "DRY_RUN deve ser true ou false." ;; esac

# 1) Arquivos candidatos e nomes repetidos.
mapfile -t files < <(ls "$MIG_DIR" | grep -E '^[0-9]{14}_.+\.sql$' | sort | awk -v min="$MIN_VERSION" 'substr($0,1,14) >= min')
[ "${#files[@]}" -gt 0 ] || fail "nenhuma migration em $MIG_DIR."
dups="$(printf '%s\n' "${files[@]}" | sed -E 's/^[0-9]{14}_//; s/\.sql$//' | sort | uniq -d)"
[ -z "$dups" ] || fail "nomes de migration repetidos (a comparação por nome ficaria ambígua): $(echo "$dups" | tr '\n' ' ')"
for f in "${files[@]}"; do
  grep -qiE '^[[:space:]]*(begin|commit)[[:space:]]*;' "$MIG_DIR/$f" \
    && fail "$f tem begin/commit próprio; a migration roda dentro da transação do script. Remova."
done

# 2) Histórico do banco.
if ! psql "$URL" -X -At -c "select 1 from supabase_migrations.schema_migrations limit 1" >/dev/null 2>&1; then
  fail "não consegui ler supabase_migrations.schema_migrations (conexão ou tabela ausente)."
fi
hist="$(psql "$URL" -X -At -F '|' -v ON_ERROR_STOP=1 -c "select version, name from supabase_migrations.schema_migrations")"

declare -A have_v have_n
while IFS='|' read -r v n; do
  [ -n "$v" ] && have_v["$v"]=1
  [ -n "$n" ] && have_n["$n"]=1
done <<<"$hist"

pending=()
for f in "${files[@]}"; do
  v="${f%%_*}"; n="${f#*_}"; n="${n%.sql}"
  if [ -z "${have_v[$v]:-}" ] && [ -z "${have_n[$n]:-}" ]; then pending+=("$f"); fi
done

summary() {
  echo "$1"
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "$1" >>"$GITHUB_STEP_SUMMARY" || true
}

mode="APLICAR"; [ "$DRY_RUN" = "true" ] && mode="SIMULACAO (dry run)"
summary "## Migrations no banco de desenvolvimento ($mode)"
summary "Arquivos conferidos: ${#files[@]}. Pendentes: ${#pending[@]}."
if [ "${#pending[@]}" -eq 0 ]; then summary "Nada a aplicar."; exit 0; fi

if [ "$DRY_RUN" = "true" ]; then
  summary "Aplicaria, nesta ordem:"
  for f in "${pending[@]}"; do summary "- \`$f\`"; done
  exit 0
fi

# 3) Aplicar, uma transação por migration (arquivo + registro no histórico).
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
done_list=()
for f in "${pending[@]}"; do
  v="${f%%_*}"; n="${f#*_}"; n="${n%.sql}"
  cat >"$tmp/wrap.sql" <<'SQL'
\i :mig
insert into supabase_migrations.schema_migrations (version, name) values (:'ver', :'nm');
SQL
  if out="$(psql "$URL" -X -q -v ON_ERROR_STOP=1 --single-transaction \
      -v mig="$MIG_DIR/$f" -v ver="$v" -v nm="$n" -f "$tmp/wrap.sql" 2>&1)"; then
    done_list+=("$f")
    summary "- aplicada: \`$f\`"
  else
    summary "- **FALHOU**: \`$f\` (nada desta migration foi gravado; as seguintes não rodaram)"
    echo "$out" | scrub | head -30 >&2
    summary "Aplicadas antes da falha: ${#done_list[@]}."
    exit 1
  fi
done
summary "Total aplicadas: ${#done_list[@]}."
