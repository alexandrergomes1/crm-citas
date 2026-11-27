# Constituição do crm-citas · versão 3.0 (rascunho)

> Vale para qualquer IA (Claude Code, Cursor, Codex…) e qualquer pessoa, em qualquer editor (padrão agents.md). Regras fixas: este arquivo não guarda estado, data nem histórico. Cada regra mora num lugar só: aqui fica a regra; o detalhe fica no guia apontado (`docs/guias/`, `DESIGN.md`, `SECURITY.md`). Tudo o que é preciso está no repositório; não dependa de conversa antiga. O que é exclusivo de uma ferramenta fica fora daqui (Claude Code: `CLAUDE.md`).

## 0. O projeto
Sistema de gestão para estúdios de estética (agenda, clientes, ficha de anamnese, comanda, caixa, financeiro, mensagens, marketing, fidelidade), para a dona do estúdio, a recepção e as profissionais, com uso intenso no celular. Tipo: sistema (SaaS). Lançamento em Espanha, Brasil e Portugal. Stack: TanStack Start (React), TypeScript, Supabase (banco Postgres), Cloudflare Workers, pnpm. Detalhe: `README.md`, `ARCHITECTURE.md`, `DESIGN.md`, `docs/produto/`.

## 1. Comandos
| Para | Comando |
|---|---|
| Instalar | `pnpm install --frozen-lockfile` |
| Rodar local | `pnpm dev` |
| Checar antes de enviar (a IA roda na sessão dela) | `pnpm typecheck` · `pnpm lint` · `pnpm test` |
| Só na CI (GitHub) | `pnpm test:e2e` (ponta a ponta) · `pnpm db:verify` (banco do zero com testes) · `pnpm build` |
| A IA nunca roda | `pnpm deploy` (publicar) · aplicar migration no banco remoto (`db push`, `psql`, conexão de IA ao banco) |

CI = os testes automáticos que o GitHub roda em cada envio. A checagem na sessão só evita envio quebrado; a prova é a do tipo de trabalho (`docs/guias/processo-sdd.md`, tabela de tipos), sempre com a CI. O que cada rotina da CI confere: `docs/guias/git-e-deploy.md`.

## 2. Fluxo (Spec-Driven Development pelo GitHub Spec Kit)
- **Regra zero:** nada é construído sem **spec aprovada**, inclusive manutenção. Fora da regra: a spec em rascunho, a pergunta ao dono e os documentos de controle.
- Etapas: planejar → aprovação do dono → construir → revisar → merge. Passo a passo, comandos do Spec Kit e os que não se usam: `docs/guias/processo-sdd.md`. A constituição do Spec Kit só aponta para este arquivo; em conflito, vale este.
- **Tipo de trabalho** (tela, funcionalidade, dados, integração, manutenção, porte, configuração, documento) decide a seção extra da spec, o guia que se segue, os revisores e a prova: tabela em `docs/guias/processo-sdd.md`; revisores em `docs/guias/revisao.md`.
- **Paradas do dono por tarefa:** tela 3 (ficha visual · spec e plano · autorização do merge); código 2 (spec e plano · autorização do merge); texto 2 (spec curta · autorização do merge). Primeira tarefa num módulo: a ficha curta do passado (§3) é a primeira parada, uma vez por módulo. Outra parada só se a construção achar algo que a spec não cobre.
- Mudança pequena da lista fechada (`docs/guias/processo-sdd.md`) usa a spec curta. Nunca tela, banco, dinheiro ou acesso.
- **Spec aprovada** = `spec.md` com "Status: Approved" e a linha "Aprovação do dono" (resposta literal, data, link da conversa).
- **Dúvidas:** no máximo 3 `[NEEDS CLARIFICATION]` por spec (o limite do próprio Spec Kit), só para o que muda tela, dinheiro, dado de cliente, acesso ou produção e não está na linha de base (§3). Vão juntas, na mesma mensagem da aprovação, cada uma com recomendação. O resto a IA decide pela prática de mercado e lista em "Assumptions", à vista na aprovação. Acesso, dado de cliente ou de saúde, dinheiro e produção nunca vão para "Assumptions"; passou de 3 dúvidas desse tipo, a tarefa se divide ou para.

## 3. Quem decide
- **Tarefa:** só o primeiro item livre de `docs/BACKLOG.md` (fila parada: `docs/guias/processo-sdd.md`) ou um pedido do dono com a citação literal. A IA não escolhe nem inventa tarefa.
- **Passado, uma vez por módulo:** antes do primeiro trabalho num módulo, uma ficha curta de sim ou não com a imagem do que o app (`previas`) mostra e o que o arquivo de `docs/produto/modulos/` diz. "Sim" fecha o passado do módulo: vira **linha de base** e não volta como pergunta. "Não" vira as mudanças pedidas, como tarefa. Registro: `docs/decisoes/AAAA-MM-DD-base-<módulo>.md`. Nunca se reconfirma item por item. Texto antigo nunca é motivo para mudar algo; mudança só com pedido do dono ou spec aprovada.
- **Três tipos de fala:**
  - **Ordem do dono** (pedido literal dele): a IA executa, pelo fluxo, e mostra o risco antes se discordar.
  - **Decisão técnica** (o que o dono não vê: código, ferramenta, teste, estrutura, processo): a IA decide pela prática de mercado, registra (suposição na spec ou `docs/adr/`) e avisa em uma linha.
  - **Pergunta** só para: o que aparece na tela, dinheiro, dado de cliente ou de saúde, acesso, produção e a ordem da fila. Decisão de design que o já aprovado (`DESIGN.md`, linha de base) responde não vira pergunta: a IA decide, registra e avisa.
- Executa só a spec aprovada; o que ela não cobre vira pergunta no molde `docs/moldes/pergunta.md`, e a IA para.
- Fala do dono também se confronta com evidência e prática de mercado; discordando, mostre o risco antes de executar.
- **Registro:** a resposta do dono fica onde é usada, no commit da própria tarefa: na spec (seções "Clarifications", "Aprovação do dono" e "Aprovação do merge"); fora de spec (ordem da fila, regra geral), em `docs/decisoes/`. Resposta registrada não volta como pergunta; só o dono reabre.
- Mudança nesta constituição, num guia de `docs/guias/`, em `DESIGN.md`, agente, skill ou trava: spec própria aprovada pelo dono; sobe a versão e entra em "Emendas". Regra nova tira ou junta outra; este arquivo fica com até 100 linhas.

## 4. Travas anti-alucinação
- **Proibido adivinhar:** biblioteca, API, esquema do banco, variável, ferramenta ou comando só depois de lido no código ou na documentação oficial.
- **Escopo estrito:** só os "Arquivos permitidos" do plano. **Reuse antes de criar**, inclusive guias e ferramentas de mercado. **Quem constrói não revisa.**
- Falhou: refaça e confira, ou relate como pendente; nunca esqueça. Mesmo erro duas vezes: pare e relate.
- Incidente vai para `docs/postmortems/` (molde); vira regra só se o mesmo tipo se repetir.
- Travas automáticas (programas que barram ações perigosas) não se contornam: `.claude/hooks/TRAVAS.md`.

## 5. Regras técnicas, segredos e dados pessoais
- Regra de negócio em `src/domain` (TypeScript puro, com teste). Banco só em `src/data`. Toda tabela tem `org_id`, RLS (trava do banco por estúdio) e teste de isolamento. Camadas: `ARCHITECTURE.md`. Detalhe por área: `docs/guias/` (`banco`, `servidor`, `telas`, `testes`, `idiomas`, `acessibilidade`, `desempenho`, `porte`) e o `AGENTS.md` da pasta.
- Toda tela segue `DESIGN.md` (fonte única de design) e `docs/guias/telas.md`.
- Segredo (senha, chave, token) nunca no código, no chat, em log ou em arquivo do repositório. Usuário e senha de teste também não. Dado pessoal nunca em log, em endereço (URL) nem em notificação.
- **Ficha de anamnese é dado de saúde.** Durante o desenvolvimento valem duas regras técnicas: nunca em log, endereço, notificação ou ferramenta de erro; um estúdio nunca vê dado de outro. Detalhe: `SECURITY.md`.

## 6. Branches e ambientes
- **Uma tarefa, uma branch** `tipo/area-assunto`, criada a partir da `previas`. Duas tarefas nunca dividem branch.
- Degraus: branch da tarefa (CI e prévia própria, onde o dono confere a tela antes do merge) → `previas` (integração e prévia) → `main` (produção). Endereços e passo a passo: `docs/guias/git-e-deploy.md`.
- Nunca enviar direto à `previas` nem à `main`: só por PR, com CI verde e revisores sem "Bloqueia".
- **Merge:** só com CI verde (ou prova local, quando falta minuto do GitHub), por pedido ao dono no molde `docs/moldes/pergunta.md` e autorização clara dele, gravada na seção "Aprovação do merge" da spec e conferida pela trava antes de juntar; depois do pedido, nenhum outro envio na branch. Passo a passo (rótulo, SHA, commit do registro, `expectedHeadSha`, prova local): `docs/guias/git-e-deploy.md`.
- **Produção:** PR `previas` → `main`, só com módulo fechado, pelo mesmo caminho (pedido de publicação, autorização clara, trava). Migration na produção, idem.
- Banco de desenvolvimento único para todas as branches. Mudança de banco é migration nova; a que já está na `previas` não se edita.
- Teto de PRs abertos e conferência de colisão: `docs/guias/processo-sdd.md`.
- Endereços (URLs) de telas novas: nome profissional em inglês, proposto na ficha da tela.
- Commits pequenos, no padrão Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`), citando a spec. Os documentos de controle (lista: `docs/guias/processo-sdd.md`) vão no PR da própria tarefa. Como contribuir: `CONTRIBUTING.md`.

## 7. Pronto quando
Spec cumprida · só arquivos permitidos · prova do tipo de trabalho (`docs/guias/processo-sdd.md`) · revisores sem "Bloqueia" · documentos de controle atualizados no mesmo PR · merge autorizado pelo dono e gravado na spec. Sem prova: "não verificado".

## 8. Como falar com o dono
- Português simples; termo técnico usual (branch, PR, merge, migration) com uma linha de explicação na primeira vez da conversa.
- **Uma mensagem por parada**, autossuficiente, no molde, com recomendação. Cada escolha tem código (ex.: P12·A). "Sim" vale quando a mensagem tem uma única pergunta com uma recomendação; com mais de uma escolha, o dono responde com os códigos.
- **Nada de listas ou documentos longos para o dono ler.** Aprovação é de um resumo curto; o detalhe fica nos arquivos.
- Ordem do dono se executa; decisão técnica se avisa em uma linha, sem perguntar; pergunta só nos assuntos do §3.
- **Toda vez que a IA parar esperando o dono, avisa no celular**, pelo meio que a ferramenta tiver (Claude Code: `CLAUDE.md`). O aviso diz em uma linha o que se espera dele, sem dado pessoal. Sem meio de aviso: diz isso ao dono em uma linha.
- Pedido para o dono fazer algo: link, cliques, nomes exatos, o que colar. Se dá para fazer com as ferramentas, faça.
- Toda conversa abre lembrando a pergunta pendente da tarefa, se houver. Uma tarefa por conversa.

## 9. Mapa
Raiz: `README.md` (o que é, como rodar) · `ARCHITECTURE.md` · `DESIGN.md` · `CONTRIBUTING.md` · `SECURITY.md` · `CHANGELOG.md` · `GLOSSARY.md`. Guias por área `docs/guias/` · fila `docs/BACKLOG.md` · estado `docs/STATUS.md` · perguntas abertas `docs/OWNER.md` · fases `docs/ROADMAP.md` · decisões do dono fora de spec `docs/decisoes/` · decisões técnicas `docs/adr/` · incidentes `docs/postmortems/` · specs `specs/` (Spec Kit) · moldes `docs/moldes/` · módulos (linha de base) `docs/produto/modulos/` · fatos de banco e servidor `docs/reference/` · travas `.claude/hooks/TRAVAS.md` · sistema antigo `docs/produto/legado/` e `docs/arquivo-antigo/` (só leitura, nunca vale como decisão).

## Emendas
| Versão | Data | O que mudou | Decisão |
|---|---|---|---|
| 1.0 | 2026-11-24 | criação | PR #132 |
| 2.0 | 2026-11-24 | base enxuta: passado fechado por módulo, ordem × decisão técnica × pergunta, até 3 dúvidas juntas, registro na spec, merge autorizado na spec, aviso no celular | `specs/20261124-223658-base-enxuta/spec.md` |
| 3.0 | rascunho | neutra para qualquer IA: detalhe em `docs/guias/` e `DESIGN.md`; aprovação por resumo curto (regra do dono de 27/11) | pendente: spec da Etapa 5 |

## Origem
`AGENTS.md` 2.0 (todo o texto de fundo) · `CLAUDE.md` · `docs/reorganizacao/06-plano-etapa5.md` §3, §5b e T13 · `docs/projeto/tecnico.md` (§Modelos fora; §Conversas: uma tarefa por conversa).
