# ADR 0002 · Fundação técnica: versões, lint de camadas, varredura de segredo, CI e Spec Kit

- **Status:** Proposto · decisões técnicas (`AGENTS.md` §5) · 27/11/2026. Vale quando a spec
  `specs/20261128-005000-fundacao-tecnica/spec.md` for aprovada pelo dono.
- **Autor:** Arquiteto de software · **Revisão:** pendente (outro papel: Engenheiro de segurança e Auditor de risco para D5 a D8,
  segurança; Revisor de código para D1 a D4 e D9 a D11)
- **Aviso ao dono:** em uma linha, junto do pedido de aprovação da spec (`AGENTS.md` §3 item 3).
- **Detalhe e fontes:** `specs/20261128-005000-fundacao-tecnica/plan.md` §2 a §9.

## Contexto
A spec da fundação pede app vazio, camadas, testes, banco local, Spec Kit, CI, gitleaks e Dependabot, com versões lidas
na fonte oficial (Assumptions 1 a 7). O repositório é público de propósito (fala do dono de 28/11/2026; o Documentador a grava em `docs/decisoes/` no PR
desta spec, R16).

## Decisões

| # | Decisão | Motivo e norma |
|---|---|---|
| D1 | Node 26.13.1 (LTS ativa) e pnpm 12.23.0, fixados em `.nvmrc` e `packageManager` | Twelve-Factor fator II (dependências declaradas e fixas). O 22 sai de suporte em 30/04/2027; o 26 vai até 30/04/2029 (calendário oficial do Node) |
| D2 | TypeScript 6.0.3, não 7.0.2 | o typescript-eslint 8.74 aceita só TS `<6.1.0` (doc oficial de versões); sem ele não há lint com tipos |
| D3 | Lint de camadas com a regra nativa `no-restricted-imports` (opção `regex`) do ESLint 10.15.0, mais `@eslint/js` e `typescript-eslint` recomendados; prova automática num teste Vitest | Clean Architecture (regra de dependência) e `ARCHITECTURE.md` §3; `AGENTS.md` §3 regra 6 (reusar o que existe: a regra é do próprio ESLint, sem pacote extra; Assumption 3). Alternativa guardada: `eslint-plugin-boundaries` se surgirem falsos alarmes |
| D4 | Versão fixada = última estável com pelo menos 3 dias de publicada; sempre exata | cadeia de fornecimento (OWASP ASVS 4.0.3 V14.2, componentes confiáveis); igual à espera padrão do Dependabot (3 dias) e acima da do pnpm (1 dia) |
| D5 | gitleaks 8.30.1 pela linha de comando, na imagem oficial fixada por digest, com `--redact`, histórico inteiro | licença MIT, sem token nem permissão de escrita, grátis também se o repositório for para organização; a gitleaks-action tem licença própria desde a v2 e pede licença em organização (README oficial). `--redact` porque o log é público (ASVS V7.1, sem segredo em registro) |
| D6 | CI com `pull_request` e `push` para `previas` e `main`, `permissions: contents: read`, sem segredo, `persist-credentials: false`, sem `pull_request_target` | ASVS V14.2 e boas práticas de segurança do GitHub Actions (menor privilégio; código de fork sem acesso a segredo) |
| D7 | Ações fixadas pelo commit completo, com a versão em comentário | uma tag pode ser movida; o commit não (boas práticas do GitHub Actions; ASVS V14.2) |
| D8 | Dependabot semanal para `npm` (pnpm) e `github-actions`, `target-branch: previas`, `cooldown` 3 dias | `AGENTS.md` §8 (nada direto à `main`); doc oficial: PR de segurança sempre vai à branch padrão, por isso o D2 da spec vai ao dono |
| D9 | Spec Kit 1.4.5 com a integração `claude`, `feature_numbering: timestamp`, **sem** a extensão `git` | `processo-sdd.md` §5; a extensão só gera branch `{number}-{slug}` (README oficial dela), incompatível com `tipo/area-assunto`; a branch fica com o DevOps na etapa 2 |
| D10 | `srcDirectory: 'src/app'` no TanStack Start; banco local com Supabase CLI 3.4.0 como dependência de dev e teste pgTAP por `supabase test db` | `ARCHITECTURE.md` §3 (telas em `src/app`); doc do Supabase (CLI fixada no `package.json`; pgTAP é a ferramenta oficial; Assumption 2) |
| D11 | Playwright 1.65.1 só com Chromium, projetos 390×844 e 1440×900 | `DESIGN.md` §9 (E15·1); Assumption 6 |

## Consequências
- Atualizar Node, TypeScript ou ESLint vira PR do Dependabot para a `previas`, revisado como qualquer outro.
- O TypeScript 7 espera o typescript-eslint; a imagem do gitleaks se atualiza à mão (o Dependabot não a vê dentro de `run:`).
- O CA11 da spec foi reescrito pelo Analista em 28/11 (o Spec Kit cria a pasta e não cria a branch), e o `processo-sdd.md`
  §5 linhas 61 a 63 ganha texto novo, aprovado pelo dono junto com a spec (`plan.md` §7).
- Para desfazer qualquer decisão: ADR novo que substitui esta linha, com o motivo.
