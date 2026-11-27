# Segurança

## O que é sensível aqui
- **Ficha de anamnese:** dado de saúde de residentes da UE (RGPD art. 9). Durante o desenvolvimento valem duas regras técnicas: nunca em log, endereço (URL), notificação, ferramenta de erro ou resposta para quem não deveria ler; um estúdio nunca vê dado de outro.
- **Dados das clientes de cada estúdio:** um estúdio nunca vê o de outro.
- **Dado pessoal** (de cliente ou da equipe): nunca em log, endereço nem notificação (inclusive o aviso no celular ao dono).
- **Segredos** (chaves, senhas, tokens): só no painel da Cloudflare e nos segredos do GitHub. Nunca no código, no chat, em log ou em arquivo do repositório. Usuário e senha de teste também não.

## Como o acesso é protegido
- **Isolamento por estúdio:** toda tabela do estúdio tem `org_id uuid not null`, RLS e teste de isolamento em `supabase/tests/` (o estúdio A não lê nem grava no B). Chave estrangeira nova entre tabelas do estúdio é composta com `org_id`. A CI reprova tabela sem RLS ou sem `org_id`, política aberta e função `security definer` mal fechada (`supabase/tests/10_security_checks.sql`).
- **No servidor:** toda ação confere login, estúdio e papel (`src/data/auth/`) antes de ler ou gravar. `service_role` só onde a RLS do usuário não alcança. Erro do banco nunca volta cru para a pessoa.
- **Páginas sem login** (`/forms/<token>`, `/pagar/<token>`, `/reset-password`, modo estúdio e outras): `no-store`, `noindex` e `Referrer-Policy: same-origin`. O link da ficha é guardado só como hash, com validade; reenviar invalida o anterior. O Worker não registra cada pedido (o endereço leva token).
- **Banco e publicação:** ninguém aplica migration no banco remoto nem publica à mão; tudo sai do GitHub. Produção só com autorização do dono.
- **Procura de segredos:** gitleaks na CI em todo PR fora de rascunho e na `main`. As travas barram ler ou gravar `.env` e variantes (`.claude/hooks/TRAVAS.md` §3).

Fatos com nomes exatos: `docs/reference/database.md` (banco) e `docs/reference/server.md` (servidor, páginas públicas, cabeçalhos). Regras de cada área: `docs/guias/banco.md` e `docs/guias/servidor.md`. Quem revisa mudança de risco: `docs/guias/revisao.md`.

## Pendências registradas (ainda não cobertas)
- **RGPD/LGPD:** nada jurídico até a produção. Antes do go-live: contratos de tratamento de dados (DPAs) em `docs/legal`; direito de acesso, apagamento e portabilidade; prazo de retenção; cifra em repouso da ficha de anamnese; apagar um estúdio inteiro (itens da fila).
- CSP completa (hoje só `frame-ancestors 'none'`) e Turnstile: previstos, não construídos. O limite de tentativas nos links públicos hoje é a contagem no banco.
- Sentry previsto com servidor na UE, sem dado pessoal e sem gravação de tela nas fichas.
- Idempotência em `/pagar` e nos webhooks: não existe; precisa de spec.

## Se algo vazar ou parecer errado
1. Avise o dono na hora, em uma linha, sem colar o dado.
2. Segredo exposto: trocar no painel do serviço (gerar novo, revogar o antigo) antes de qualquer outra coisa.
3. Dado de cliente exposto: anotar o quê, de quem e desde quando; o dono decide a comunicação (RGPD: até 72 horas para avisar a autoridade, se houver risco às pessoas).
4. Relato em `docs/postmortems/` (molde `docs/moldes/postmortem.md`).

## Origem
`SECURITY.md` atual · `AGENTS.md` 2.0 §5 · `docs/projeto/tecnico.md` §Dados · `docs/reference/database.md` (§Nomes e estruturas, §Não coberto) · `docs/reference/server.md` · `docs/reference/stack.md` (§Hospedagem, §Observabilidade) · `.claude/hooks/TRAVAS.md` §3 · `.claude/rules/banco-dados.md` · `wrangler.jsonc` · `CLAUDE.md` (aviso no celular sem dado pessoal).
