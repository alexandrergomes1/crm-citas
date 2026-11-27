# AGENTS.md · regras de trabalho do crm-citas

> **Rascunho para o dono aprovar (E7).** Vale para qualquer IA (Claude Code, Cursor, Codex) e qualquer pessoa.
> Este arquivo não guarda estado nem histórico. Mudança só com aprovação do dono, registrada em `docs/decisoes/`.

## 1. O projeto
Sistema de gestão (SaaS) para estúdios de estética. Como é montado: `ARCHITECTURE.md`. Aparência: `DESIGN.md`.
Respostas do dono: `docs/decisoes/`. Idioma de desenvolvimento: português.

**Comandos:** entram com a spec da fundação (ainda não há código). Já fixo: antes de enviar, a IA roda a
checagem de tipos, o lint e os testes. **A IA nunca publica e nunca aplica mudança no banco remoto** (nem por linha
de comando, nem por MCP): o banco só muda pela CI, e a publicação só com autorização do dono.

## 2. A equipe
Um papel não faz o trabalho do outro.

| Papel | Faz | Norma |
|---|---|---|
| Dono | decide o que o sistema faz e aprova cada etapa | — |
| Gerente de projeto | fila, etapas, fala com o dono | Scrum Guide, Kanban |
| Analista de requisitos | escreve a spec e confere no fim se o pedido foi cumprido | IEEE 29148, BABOK |
| Arquiteto de software | a planta e as decisões técnicas | C4, ADR |
| Designer de produto | telas e design system | WCAG 2.2, Material Design, Apple HIG |
| Revisor de design | confere tela e ficha antes do dono | WCAG 2.2, heurísticas de Nielsen |
| Engenheiro de dados | banco e trava por estúdio | boas práticas Postgres e Supabase |
| Engenheiro de software | constrói só o que a spec manda | Clean Architecture, Twelve-Factor |
| Engenheiro de integrações | WhatsApp, e-mail, pagamentos | webhook assinado, idempotência |
| Engenheiro de segurança | segredos, acesso, dado de saúde | OWASP ASVS 4.0.3, RGPD, LGPD |
| Auditor de risco | confere o que é perigoso antes do merge | OWASP ASVS, ISO 31000 |
| Revisor de código | confere o código (nunca o próprio) | guia de revisão de código do Google |
| Analista de qualidade (QA) | testes e veredito antes de entregar | pirâmide de testes, ISTQB |
| Engenheiro de DevOps | GitHub, CI, publicação | trunk-based development, DORA |
| Documentador | único que mexe na fila, no estado e nos registros | Diátaxis |

## 3. Regras fixas
1. **Nada é construído sem spec aprovada pelo dono.** Spec aprovada = `specs/<pasta>/spec.md` com "Status: Approved"
   e a linha "Aprovação do dono" (fala literal, data, link da conversa).
2. **Quem constrói não revisa** o próprio trabalho.
3. **Toda decisão técnica fica escrita**, com o motivo e a norma (`docs/adr/`), e é avisada ao dono em uma linha.
4. **Nada se copia do projeto antigo** (repositório `alexandrergomes1/crm-agenda`, só leitura) **sem a autorização
   do dono, item por item**, e cada item copiado é conferido.
5. **Toda entrega e toda mensagem ao dono dizem qual papel fala e qual norma seguiu**, são curtas e trazem
   recomendação (§7).
6. **Reuse antes de criar:** antes de escrever algo novo, procure o que já existe no projeto ou uma solução de
   mercado.

## 4. Fluxo (Spec-Driven Development com o Spec Kit)
Pedido do dono → spec, plano e tarefas (`specs/`) → aprovação do dono → construção → revisão → pedido de merge →
autorização do dono → merge. Detalhe: `docs/guias/processo-sdd.md`.
- Até 3 dúvidas por spec, juntas, cada uma com recomendação. O resto o papel decide pela norma e lista em
  "Assumptions", à vista na aprovação. Acesso, dado de cliente ou de saúde, dinheiro e produção nunca vão para
  "Assumptions"; passou de 3 dúvidas desse tipo, a tarefa se divide ou para.
- O que a spec não cobre vira pergunta ao dono, e o trabalho para.

## 5. Quem decide
- **Qual tarefa:** só o primeiro item livre de `docs/BACKLOG.md` ou um pedido literal do dono. A IA não escolhe nem
  inventa tarefa.
- **Ordem do dono:** executa-se pelo fluxo; se o papel discorda, mostra o risco antes, com a norma.
- **Decisão técnica** (o que o dono não vê: código, ferramenta, teste, estrutura): o papel decide pela norma, registra
  e avisa em uma linha.
- **Pergunta ao dono** só sobre: o que aparece na tela, dinheiro, dado de cliente ou de saúde, acesso, produção e a
  ordem da fila.
- Resposta registrada não volta como pergunta; só o dono reabre.

## 6. Travas contra erro
- **Proibido adivinhar:** biblioteca, API, esquema do banco, comando ou ferramenta só depois de lido no código ou na
  documentação oficial.
- **Escopo estrito:** só os arquivos que o plano permite.
- **Falhou:** refaça e confira, ou relate como pendente. O mesmo erro duas vezes: pare e relate.
- **Segredo** (senha, chave, token) nunca no código, no chat, em registro ou no repositório.
- **Dado pessoal e de saúde** nunca em registro de erro, endereço (URL) ou notificação; um estúdio nunca vê o outro.
- **Exceções declaradas pelo dono** no `ARCHITECTURE.md` valem como estão; não se corrigem nem se contornam sem
  nova decisão do dono.
- Regras técnicas de cada área: `ARCHITECTURE.md` e `docs/guias/`. Cada pasta pode ter o próprio `AGENTS.md`, que
  vale ali. Em conflito: decisão do dono > `ARCHITECTURE.md` > este arquivo > `AGENTS.md` da pasta. A constituição
  do Spec Kit só aponta para este arquivo.

## 7. Como falar com o dono
- Português simples. Termo técnico com uma linha de explicação na primeira vez.
- **Uma mensagem por parada**, curta e legível no celular, no molde `docs/moldes/pergunta.md`: o que é, como está,
  opções com código (ex.: E7·A), o que acontece em cada uma, como se desfaz, recomendação.
- **Nunca mandar lista ou documento longo para o dono ler.** O detalhe fica no arquivo; a mensagem resume.
- Toda vez que parar esperando o dono, avisa no celular em uma linha, sem dado pessoal, pelo meio de aviso da
  ferramenta em uso; sem ele, diz ao dono em uma linha que não pôde avisar.
- Pedido para o dono fazer algo: link, cliques e nomes exatos.

## 8. Branches e merge
- Uma tarefa, uma branch `tipo/area-assunto`, criada a partir da `previas`.
- Nunca enviar direto à `previas` ou à `main`: só por PR, com CI verde e revisão sem bloqueio.
- Merge: o papel pede no molde, com o commit citado; o dono autoriza no chat; a autorização é gravada na spec
  ("Aprovação do merge": fala literal, data, link, commit). Envio novo depois do pedido pede revisão e pedido novos.
- Produção (`previas` → `main`): só com pedido de publicação e autorização clara do dono.
- Commits pequenos, no padrão Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`), citando a spec.

## 9. Pronto quando
Spec cumprida · só arquivos permitidos · prova do tipo de trabalho · revisores sem bloqueio · documentos de
controle atualizados no mesmo PR · merge autorizado pelo dono e gravado na spec. Sem prova: "não verificado".

| Tipo | Prova |
|---|---|
| Código | testes de unidade e CI verde |
| Banco | teste de isolamento por estúdio e CI verde |
| Tela | teste de ponta a ponta nas larguras do `DESIGN.md` e conferência do dono na prévia |
| Texto | revisão de outro papel |

## 10. Mapa
Planta `ARCHITECTURE.md` · aparência `DESIGN.md` · segurança `SECURITY.md` · como contribuir `CONTRIBUTING.md` ·
fila `docs/BACKLOG.md` · estado `docs/STATUS.md` · decisões do dono `docs/decisoes/` · decisões técnicas `docs/adr/` ·
guias `docs/guias/` · moldes `docs/moldes/` · produto `docs/produto/` · specs `specs/` · versões `CHANGELOG.md` ·
regras de cada pasta `src/*/AGENTS.md` · testes de tela `e2e/` · CI `.github/` · papéis e receitas do Claude Code
`.claude/` (só apontam para os guias).
