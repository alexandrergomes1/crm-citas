# Backup do banco — como funciona e como ligar

> **Estado (15/11):** o agendamento está **desligado**. O backup e o teste de restauração só rodam à mão, pela aba Actions. Motivo: o banco de teste consumia minutos do GitHub sem valor. Na virada, eles voltam a rodar sozinhos: ver `docs/runbooks/go-live.md`, "No dia".

## Como funciona (quando o agendamento estiver ligado)
- Todo dia às 03:17 (UTC) o GitHub copia o banco (papéis, estrutura e dados), tranca com uma senha forte (AES-256) e guarda no Cloudflare R2, na União Europeia. Se o Backblaze estiver configurado, guarda uma segunda cópia lá.
- Pastas: `diario/` (apagado após 8 dias), `semanal/` aos domingos (35 dias), `mensal/` no dia 1 (100 dias).
- Todo dia 2 do mês, o GitHub baixa o backup mais recente, destranca, restaura num banco descartável e confere se clientes, agendamentos e estúdios voltaram. Também falha se o último backup tiver mais de 2 dias.
- Qualquer falha: o GitHub manda e-mail para o dono do repositório.
- Começa apontando para o banco de desenvolvimento (dados de teste) para provar que funciona. Na virada, os segredos passam para o banco de produção (`docs/runbooks/go-live.md`, "No dia").

## Passo a passo do Alexandre — **já feito em 13/11**, guardado para refazer se precisar
O backup foi provado nesse dia (feito e restaurado num banco descartável). Nada abaixo está pendente, a não
ser o item 4 (Backblaze), que vai com a virada. O backup copia só o banco: as fotos da anamnese ainda não entram
(item 38 de `docs/ICEBOX.md`).
Regra: nenhuma chave ou senha passa pelo chat. Copie de um site e cole direto no GitHub.

### 1. Cloudflare R2 (obrigatório)
1. ~~Criar o bucket~~ feito em 13/11: `crm-agenda`, jurisdição União Europeia.
2. No bucket `crm-agenda` (https://dash.cloudflare.com/af26831f4349366d5921c159c982e49f/r2/overview › clique em `crm-agenda`) › aba **Settings**:
   - **Public access / R2.dev subdomain / Custom domains**: deixe tudo desligado.
   - **Local uploads**: desligado (não ajuda: o envio vem do GitHub, nos EUA).
   - **Object lifecycle rules** › **Add rule**, três vezes: nome `diario`, prefixo `diario/`, "Delete objects" após **8** dias · nome `semanal`, prefixo `semanal/`, **35** dias · nome `mensal`, prefixo `mensal/`, **100** dias.
   - Logs de acesso / notificações de eventos: não ligar (não precisamos e geram custo/ruído).
3. Chave de acesso: https://dash.cloudflare.com/af26831f4349366d5921c159c982e49f/r2/api-tokens › **Create Account API token** (ou "Create API token") › Token name: `backup-github` › Permissions: **Object Read & Write** › Specify bucket(s): **Apply to specific buckets only** › `crm-agenda` › TTL: Forever › **Create API Token**.
4. A tela seguinte mostra **Access Key ID** e **Secret Access Key** uma única vez. Não feche essa aba até o passo 5.

### 2. Senha do backup (obrigatório)
No seu gerenciador de senhas, gere uma senha de 40 caracteres ou mais e salve como "Backup crm-agenda". **Sem ela, nenhum backup abre.** Guarde também fora do gerenciador (papel num lugar seguro).

### 3. Endereço do banco (obrigatório)
1. Abra o projeto de desenvolvimento: https://supabase.com/dashboard/project/qjcabltvchmzmpigiyrv
2. Botão **Connect** (no topo) › aba **Connection String** › Method: **Session pooler** › copie o endereço que começa com `postgresql://postgres.`.
3. Troque `[YOUR-PASSWORD]` pela senha do banco. Se não souber: https://supabase.com/dashboard/project/qjcabltvchmzmpigiyrv/database/settings › **Reset database password** › gere e salve no gerenciador (o app não usa essa senha; é seguro trocar).

### 4. Backblaze B2 (opcional agora, obrigatório antes da virada)
Fica para depois. O backup roda sem ele.

### 5. Colar no GitHub
Abra https://github.com/alexandrergomes1/crm-agenda/settings/secrets/actions/new e crie um segredo por vez (Name + Secret › **Add secret**), voltando ao mesmo link para o próximo:

| Name (exato) | Secret (o que colar) |
|---|---|
| `SUPABASE_DB_URL` | endereço do passo 3, já com a senha |
| `BACKUP_PASSPHRASE` | senha do passo 2 |
| `R2_ENDPOINT` | `https://af26831f4349366d5921c159c982e49f.eu.r2.cloudflarestorage.com` |
| `R2_BUCKET` | `crm-agenda` |
| `R2_ACCESS_KEY_ID` | Access Key ID do passo 1.4 |
| `R2_SECRET_ACCESS_KEY` | Secret Access Key do passo 1.4 |

### 6. Avisar o Claude
Diga "segredos do backup cadastrados". O Claude dispara o primeiro backup e o teste de restauração e mostra o resultado.

## Custo
Nenhum uso de IA: é um script do GitHub Actions. Consome cerca de 2 min por dia + 10 min no teste mensal (≈ 70 min/mês dos 2.000 min grátis do GitHub) e poucos MB no R2 (grátis até 10 GB).

## Restaurar de verdade (incidente)
Baixar o arquivo do R2, destrancar com a senha (`gpg -d arquivo.tar.gz.gpg | tar -xz`) e aplicar `roles.sql`, `schema.sql` e `data.sql` num projeto Supabase novo, nessa ordem. Feito por um agente com ok do Alexandre; o teste mensal é o ensaio disso.
