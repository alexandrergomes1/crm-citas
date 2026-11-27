# Dados do projeto

Endereços, nomes e números próprios deste projeto. Skills e agentes de `.claude/` não repetem nada
daqui: apontam para este arquivo. Fatos do banco: `docs/reference/database.md`. Fatos do servidor:
`docs/reference/server.md`. Para reaproveitar a base noutro projeto, copie `.claude/` e os moldes e
reescreva estes três documentos.

## Identidade
| | |
|---|---|
| Nome provisório | crm-agenda |
| O que é | SaaS de gestão para estúdios de estética: agenda, clientes, ficha de anamnese, comanda, financeiro |
| Dono (decide tudo) | Alexandre |
| Língua de trabalho | português simples, sem jargão |
| Dados sensíveis | ficha de anamnese = dado de saúde de residentes da UE (RGPD art. 9) |

## Repositório e branches
| | |
|---|---|
| Repositório | https://github.com/alexandrergomes1/crm-agenda |
| Link de arquivo | `https://github.com/alexandrergomes1/crm-agenda/blob/<branch>/<caminho>` |
| Branch de integração (base de todo PR) | `previas` |
| Branch de produção | `main` |
| Repositório de origem do porte | `alexandrergomes1/beauty-system` (Next.js) |

## Ambientes
| Ambiente | Endereço | Branch | Banco |
|---|---|---|---|
| Prévia (onde o dono confere) | https://crm-citas-previas.alexandrergomes.workers.dev | `previas` | desenvolvimento |
| Produção | https://crm-citas.alexandrergomes.workers.dev | `main` | desenvolvimento até a virada; depois, produção |

## Bancos (Supabase)
| Uso | Projeto | Referência |
|---|---|---|
| Desenvolvimento, prévias e backup de teste | Beauty System | `qjcabltvchmzmpigiyrv` |
| Produção (vazio até a virada) | crm-agenda | `bwpltaufyenmumsfaczb` |

**A conexão MCP `Supabase-Crm-Agenda` do Claude Code aponta para a produção** (`bwpltaufyenmumsfaczb`).
Por isso `apply_migration` e `execute_sql` ficam bloqueados pela trava (`.claude/hooks/guarda.mjs`).
As ferramentas de leitura da conexão (listar tabelas, advisors, logs) continuam liberadas.

## Stack
`docs/reference/stack.md` é a fonte. Resumo: TanStack Start em Cloudflare Workers, Supabase (Postgres com
RLS por `org_id`), TypeScript estrito, Vitest, Playwright, pnpm.

## Pastas e arquivos que as skills citam
| O quê | Onde |
|---|---|
| Regra de negócio pura | `src/domain` |
| Único lugar que fala com o banco | `src/data` |
| Checagens de acesso | `src/data/auth` |
| Componentes de tela | `src/design-system` |
| Adaptador de navegação | `src/lib/nav` |
| Migrations | `supabase/migrations/` (nome com 14 dígitos: `AAAAMMDDHHMMSS_descricao.sql`) |
| Testes de banco | `supabase/tests/` |
| Teste do orçamento de idas ao banco | `src/data/supabase-calls.test.ts` |
| Tipos do banco | `src/data/database.generated.ts` (gerado por `pnpm db:types`) |
| Testes de ponta a ponta | `e2e/` |
| Specs de tela | `specs/NNN-nome/` pelo Spec Kit (molde em `.specify/templates/overrides/`); antigas em `docs/specs/screens/` |
| Specs de funcionalidade | `specs/NNN-nome/` pelo Spec Kit (`docs/projeto/tecnico.md` §Spec Kit); antigas em `docs/specs/` |
| Planos de execução (não são spec aprovada) | `docs/specs/plans/` |
| Livro de padrões de tela | `docs/design/padroes/` |
| Registro de decisões de design | `docs/decisoes/historico/registro-ate-2026-11-24.md` |
| Registros de decisão de processo e técnica | `docs/adr/` (molde: `docs/moldes/adr.md`) |
| Índice do design system (camadas 1 a 9) | `docs/design/design-system/README.md` |
| Imagens de referência para montar ficha | `docs/design/padroes/livro-2026-11-12`, `docs/design/decisoes/historico`, `docs/design/decisoes/mesa/img`, `docs/design/v25-mockups`, `docs/fresha-prints-referencia`, `docs/referencias-mercado` |
| Método antigo de ficha (histórico, não usar) | `docs/design/decisoes/gerador/` e a "Mesa" |

## Tela
| | |
|---|---|
| Larguras de conferência | celular 390x844 e computador 1440x900 |
| Fonte | Geist (única) |
| Alvo de toque mínimo | 40 px no computador, 44 px no celular (registro de design, CAM4-02); botão só-ícone da barra do computador com 32 px (AG9) |
| Limite de linhas | 300 por arquivo de tela, 500 por arquivo |
| Design system publicado | Beauty System Design System, https://claude.ai/artifact/YBjctyzxXKNjDnf7ArZKGo (nome global dos componentes no canvas: `BeautySystemDesignSystem_a11b4e`) |
| Páginas sem login | com token no endereço: `/forms/<token>`, `/pagar/<token>`, `/reset-password`; e o modo estúdio `/<estúdio>/anamnese-tablet`. Lista completa e cabeçalhos: `docs/reference/server.md` |
| Glossário de termos | ainda não existe como arquivo; os termos em uso estão no registro de design |

### Como ver uma tela
- **Antes do merge:** a CI roda os testes de ponta a ponta nas duas larguras; a captura de cada tela (390 e 1440) vai como artefato `capturas-telas` do PR (aba Summary da execução do E2E; some em 90 dias), feita por `e2e/capturas-telas.spec.ts` num passo que não bloqueia o merge. Nada disso vai para o git. Na sessão de nuvem do Claude Code não há banco local, então **não dá para abrir a tela com dados**; tela nova entra na lista `TELAS` desse teste.
- **Depois do merge na branch de integração:** a prévia mostra a tela. É onde o dono do projeto confere.
- Nunca escreva usuário ou senha de teste em arquivo do repositório nem no chat.

## Pacotes de ferramentas (método de mercado)
Na nuvem, a sessão só carrega os pacotes **ligados na conta do claude.ai** do dono. O
`.claude/settings.json` do repositório não os instala (documentação do Claude Code, "cloud
environments": plugins declarados no repositório não são instalados numa sessão na nuvem). O início
de sessão (`.claude/hooks/inicio-de-sessao.mjs`) confere se as peças abaixo estão no disco e avisa no
topo quando falta alguma.

| Pacote (nome no diretório de plugins do claude.ai) | Peças que o projeto usa |
|---|---|
| design-skills | design-critique, accessibility-audit, interaction-design, ux-writing, design-systems, design-ops |
| Design (Anthropic) | design-handoff |
| Superpowers | verification-before-completion, systematic-debugging, brainstorming, writing-plans |
| commit-commands | commit |
| Backend Design | explain-this-query, hunt-n-plus-one |

**Como ligar:** a IA mostra na conversa o cartão de instalação (ferramenta de sugestão de plugins) e
o dono clica **Add** em cada um; vale para a conta e para as próximas sessões. Peças de cada pacote que
o projeto não quer continuam bloqueadas em `.claude/settings.json`.

**Quando chegam:** numa conversa que o dono abre, a cópia dos pacotes da conta leva até 2 minutos e
termina depois do aviso do início. Numa conversa criada por outra conversa eles nunca chegam (e as
variáveis do ambiente também não): por isso a IA não abre conversa (`docs/projeto/tecnico.md` §Conversas). Os
pacotes são carregados por inteiro.

**Reforço, não portão.** Pacote faltando é aviso: o trabalho segue com as listas do repositório e o
que dependia dele sai como "não verificado" (`CLAUDE.md`).

**Só estes 12 ficam ligados neste projeto** (`true` em `enabledPlugins`; skill só carrega quando é chamada): superpowers, design-skills, design,
skill-creator e claude-code-setup (criar skill e recomendar automação, sem conector), commit-commands, backend-design, supabase, playwright (ferramentas do `ui-qa`),
skill-reviewer e claude-md-management (`/revise-claude-md`), e frontend-design (trabalho visual, com o design system como briefing; regras nas skills `ui-standards` e `design-decision`). Os outros plugins da conta continuam na
conta, para outros trabalhos, e aqui ficam desligados (para o site futuro: marketing, brand-voice, searchfit-seo e humanizer
se ligam trocando `false` por `true`) por `enabledPlugins` com `false` em
`.claude/settings.json`. Não existe "desligar todos menos estes" nem curinga (`"*@synced": false`
não funciona, testado em 20/11): plugin novo na conta entra ligado até ganhar a sua linha; o início de
sessão avisa quando aparece plugin sem linha no settings. Nome de
cada plugin: `claude plugin list`. Desligar compensa: plugins trazem conectores (Gmail, Shopify,
QuickBooks…) cujas instruções entram em toda conversa, e a lista de skills tem teto de 1% do contexto,
que corta as descrições quando há skills demais (decisão: `docs/adr/2026-11-20-plugins-por-projeto.md`).

## Comandos
| Para | Comando |
|---|---|
| Subir o app na máquina | `pnpm dev` (porta 3000) |
| Recriar o banco do zero e rodar os testes de banco | `pnpm db:verify` (precisa de `psql` e de um Postgres local) |
| Regenerar os tipos do banco | `pnpm db:types` |
| Testes dos hooks do Claude Code | `node .claude/hooks/guarda.test.mjs` e `node .claude/hooks/inicio-de-sessao.test.mjs` |

Tipos, lint, testes e build rodam na CI: não rode na máquina para provar (`docs/projeto/tecnico.md` §CI).

## Conferências automáticas (GitHub, sem IA)
Tipos, lint, testes de unidade, build, replay de todas as migrations com os testes de banco,
testes de ponta a ponta em 390 e 1440, procura de segredos. Detalhe em `docs/projeto/tecnico.md` §CI.

## Fatos do GitHub
- Repositório privado no plano gratuito do GitHub: **não existe regra de proteção de branch**. A barreira é a trava do Claude Code (`.claude/hooks/guarda.mjs`, `.claude/hooks/TRAVAS.md`), que só vale para o Claude. Por isso `ci.yml` e `seguranca.yml` também rodam no `main` como segunda checagem.
- Branch padrão `previas`; Actions com token só de leitura, sem criar nem aprovar PR; alertas do Dependabot ligados; orçamento de US$ 10 do Actions; exclusão automática da branch depois do merge ligada (Settings › General › Pull Requests).
- Aplicativos instalados no GitHub: ChatGPT Codex Connector (sem revisão automática), Claude, Claude Design Import, Cloudflare Workers and Pages, Google AI Studio, Vercel.
- Revisão trimestral de automações e conexões: manual, sem IA, cerca de 30 minutos. Conferir os aplicativos instalados no GitHub (Settings › Applications › Installed GitHub Apps), os projetos conectados na Vercel e na Cloudflare e os workflows com agendamento. Desligar o que duplica ou não tem dono.
