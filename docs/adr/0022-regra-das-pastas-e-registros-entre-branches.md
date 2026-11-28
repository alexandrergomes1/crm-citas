# ADR 0022 · Regra das pastas (specs × docs) e como os registros passam entre branches

- **Status:** Proposto (vira Aceito com a "Aprovação do dono" da spec `specs/20261128-180247-processo-revisao/`)
- **Autor:** Arquiteto de software · **Norma:** modelo C4 (nível de documentação), ADR (Nygard), Diátaxis (tipo de
  documento), trunk-based development (integração)
- **Revisão:** pendente (Gerente de projeto, etapa 5b)
- **Aviso ao dono:** uma linha na mensagem de aprovação da spec (`AGENTS.md` §3 item 3; RF-20)

## Contexto
1. O dono perguntou: "na pasta specs ta cheeeeeio de arquivos, auditorias, etc... isso ta certo? nao vai se perder no
   meio do caminho?". Hoje não há regra escrita do que fica em `specs/<pasta>/`; a auditoria do processo e as ideias
   do antigo foram gravadas dentro da pasta da Agenda, e as 4 revisões de conversa estão fora do repositório.
2. A fila com o item 4b, as decisões de 28/11, o estado e a auditoria estão só na `feat/agenda` (até `85501a0`). A
   branch `chore/processo-revisao` nasce da `previas` e precisa deles.
3. Fato conferido nesta sessão: copiar o `docs/decisoes/2026-11-27-fundacao.md` da `feat/agenda` sem mudança
   **reprova a CI** (job `travas`, passo "Aprovações com prova"): a linha E26·1·B, que já está na `previas`, foi
   editada na `feat/agenda`, e a trava só aceita acrescentar linha. Com a linha E26·1·B igual à da `previas` e a
   substituição numa linha nova, a mesma trava passa (teste numa pasta temporária, saída 0).

## Decisão
1. **Regra:** `specs/<pasta>/` guarda só o que nasce e acaba com a tarefa; o que vale depois dela, ou para mais de
   uma, vai para `docs/`. O texto da regra mora num arquivo só, `docs/guias/pastas.md`, apontado pelo `AGENTS.md`
   §10. Pasta nova em `docs/` só por ADR. Arquivo que não cabe em nenhum lugar não se grava: o Documentador aponta e
   o Arquiteto decide o lugar em ADR.
2. **Novo lugar:** `docs/auditorias/` para auditorias de processo e revisões de conversa (subpasta `conversas/`).
   Leituras do projeto antigo seguem em `docs/produto/avaliacao-crm-agenda/` (já existe).
3. **Exceção nomeada:** `specs/20261128-005000-fundacao-tecnica/travas-claude-propostas/` fica onde está: a CI lê
   `specs/*/travas-claude-propostas/` e o item 2 da fila não fechou (E38·A1). Sai quando o PR das travas do Claude
   mover os arquivos para `.claude/`.
4. **Registros entre branches:** a branch do 4b traz da `feat/agenda` (`85501a0`) cópias exatas da fila, do estado e
   das duas specs com a "Aprovação do merge" (itens 3 e 4), e as linhas novas das decisões **com a E26·1·B igual à
   da `previas`** e a substituição como linha nova. Nada de merge nem cherry-pick da `feat/agenda` (traria spec,
   plano, ficha, ADR 0006 e 0021 e o `DESIGN.md` da Agenda, que não estão autorizados a entrar na `previas`).
5. **Ordem de merge:** primeiro o 4b na `previas`; depois a `feat/agenda` traz a `previas` por merge e, nos
   documentos de controle, fica com a versão da `previas`. Até o merge do 4b, a `feat/agenda` não recebe commit
   nesses arquivos (a Agenda está parada por ordem do dono).

## Motivo e norma
- Diátaxis separa documento de trabalho (de uma tarefa) de referência (que dura); C4 pede um lugar fixo por nível.
- Cópia exata e uma só direção de integração (trunk-based) deixam o conflito previsível: só nos arquivos de
  controle, e sempre resolvido para o lado da `previas`, que é o mais novo e contém o outro.
- A trava de aprovações (ADR 0003) é regra aprovada; a cópia se ajusta a ela, nunca o contrário.

## Consequências
- O merge `previas` → `feat/agenda` terá conflito esperado em `docs/BACKLOG.md`, `docs/STATUS.md` e
  `docs/decisoes/2026-11-27-fundacao.md`; resolve-se com a versão da `previas` e confere-se com
  `git diff 85501a0 HEAD -- <arquivo>` (só pode aparecer o que o 4b acrescentou). Isso também conserta, na Agenda,
  a linha E26·1·B que reprovaria a CI do PR dela.
- A `feat/agenda` apaga a cópia velha da auditoria, move `ideias-do-antigo.md` para
  `docs/produto/avaliacao-crm-agenda/agenda-ideias.md` e corrige os links (linha no item 5 da fila).
- As outras branches de módulo seguem a mesma regra quando forem trabalhadas: trazem a `previas` antes.
- Para desfazer: um ADR novo que substitui este; os arquivos voltam com `git mv`.
