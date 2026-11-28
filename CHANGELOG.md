<!-- CHANGELOG.md: o que entrou em cada versão. Conteúdo a escrever, com aprovação do dono. -->
# Versões

## Ainda não lançado

### Em pedido de merge (PR #7) · item 4a da fila, Entrar e camada de serviço
Spec [`specs/20261128-030000-entrar-servico/`](https://github.com/alexandrergomes1/crm-citas/tree/feat/entrar-servico/specs/20261128-030000-entrar-servico)
aprovada pelo dono; o merge ainda espera a autorização dele.
- Telas Entrar, Escolher empresa e Sua conta, em português, espanhol e inglês; tela inicial só com a barra do topo.
- Sessão e camada única de serviço: as portas por onde o app fala com o banco, com a matriz de permissões
  (ADR 0020) e registro de auditoria.
- Proteção do Entrar: limite de tentativas e recusa de pedido forjado vindo de outro site.
- Banco local: migrations novas com testes de isolamento por estúdio; nada aplicado em banco remoto.
- Testes de integração e de telas (390 e 1440 px) rodando contra o banco local por `scripts/banco-local.mjs`.

### Em revisão (PR #5, rascunho) · item 3 da fila, ligar o banco
Spec `specs/20261128-010000-banco-ligacao/` ainda sem aprovação do dono; nada foi juntado.
- Fase A: migrations de estúdios, membros, trava por estúdio e políticas base (ADR 0005), com 77 testes de banco.
- Nada aplicado em banco remoto. Fase B (aplicar no banco de desenvolvimento pela CI) espera E24·1, E24·2 e a
  aprovação da spec.

### Juntado (PR #4, E37·A) · item 2 da fila, fundação técnica
Spec `specs/20261128-005000-fundacao-tecnica/` ainda sem aprovação do dono; nada foi juntado.
- App vazio (TanStack Start) com as quatro camadas, lint de camadas, Vitest e Playwright (390 e 1440 px).
- Banco local do Supabase com migration vazia e teste pgTAP; nada liga a banco remoto.
- CI no GitHub Actions (`verificar`, `telas`, `banco`, `segredos`, `travas`), gitleaks e Dependabot.
- Travas do projeto antigo (ADR 0003): gancho de envio em `.githooks/`; as do Claude Code só propostas, não ligadas.
- Comandos no `AGENTS.md` §1 e no `docs/guias/processo-sdd.md` §5 (R15), à espera da aprovação do dono.
