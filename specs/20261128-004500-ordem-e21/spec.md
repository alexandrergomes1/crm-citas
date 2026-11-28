# Spec · Ordem de entrada das partes (E21·1) e repositório público

- **Pasta:** `specs/20261128-004500-ordem-e21/` · **Branch:** `docs/ordem-e21`
- **Tipo:** texto e regras · **Escrita por:** Analista de requisitos · **Norma:** IEEE 29148 e BABOK
- **Status:** Approved
- **Aprovação do dono:** "E34a" (E34·A: aprovar a spec e juntar) · 28/11/2026 · https://claude.ai/code/session_018cV8b9epaQJNqguG5c5Aqb · gravado pelo Analista de requisitos (E16·3).
- **Aprovação do merge:** "E34a" · 28/11/2026 · https://claude.ai/code/session_018cV8b9epaQJNqguG5c5Aqb · commit `21d2c38` (PR #3), com a exceção "sem CI" do E19; juntado depois do PR #2, com a branch atualizada pela `previas` · gravado pelo Engenheiro de DevOps.

## 1. Pedido literal do dono (28/11/2026, https://claude.ai/code/session_018cV8b9epaQJNqguG5c5Aqb)
- **E21·1:** "E21-1: Módulos, inverta o partes do sistema pelo "depois um por vez". Pois esses do item 2(partes do
  sistema) é novo e entra depois dos "um por vez"."
- **E19·1 (troca), visibilidade:** "Eu deixei público o projeto para vc ter os actions pra usar se preciso pq no
  privado tá sem limite. Salvo se conseguires mudar entre público e privado qdo precisar ."

## 2. O que muda
1. **`ARCHITECTURE.md` §2, coluna "Quando entra"** — nova ordem (E21·1, substitui a E4·3):
   núcleo → outros módulos, um por vez → painel admin → cadastro e cobrança da assinatura → portal público
   (reserva online) → marketplace → API pública.
2. **`ARCHITECTURE.md` §2, frase da ordem** — passa a citar a E21·1 (no lugar da E4·3) e a dizer que as partes novas
   da tabela entram depois dos outros módulos.
3. **`SECURITY.md` §1** — o repositório passa a ser público; com isso, o aviso privado de falha do GitHub passa a
   existir. Diz-se só esse fato: o meio de aviso continua o da E14·1 (avisar direto ao dono, em particular).

## 3. O que não muda
- A fila (`docs/BACKLOG.md`): muda no PR do item 1, não aqui.
- O núcleo da primeira versão (E3·2) e a condição da API pública (E4·1).
- A visibilidade em si (assunto de acesso, do dono): esta spec só registra o estado atual (público). Trocar entre
  público e privado ("Salvo se conseguires mudar...") não faz parte desta tarefa.
- Qualquer outra seção do `ARCHITECTURE.md` e do `SECURITY.md`.

## 4. Critérios de aceite
- **CA1.** Na tabela do §2, "Quando entra" mostra, nesta ordem: App do estúdio = primeira versão (núcleo); Painel
  admin = depois dos outros módulos (um por vez); Cadastro e cobrança = depois do painel admin; Portal público =
  depois da cobrança; Marketplace = depois da reserva online; API pública = depois do marketplace, só quando
  precisarem (E4·1).
- **CA2.** A frase da ordem no §2 cita a E21·1, não cita mais a E4·3 como ordem em vigor, e mantém o núcleo da E3·2.
- **CA3.** O `SECURITY.md` não diz mais que o repositório é privado; diz que é público e que o aviso privado do
  GitHub existe, sem mandar usá-lo nem trocar o meio da E14·1.
- **CA4.** Só mudam `ARCHITECTURE.md` e `SECURITY.md` (mais os registros de controle da etapa 11).
- **CA5.** Revisão de outro papel que não escreveu o texto, sem "Bloqueia" (`AGENTS.md` §9, tipo texto).

## 5. Dúvidas
Nenhuma: as duas decisões já foram dadas pelo dono.

## 6. Assumptions
- **A1.** "Inverter pelo depois um por vez" foi lido como: os outros módulos vêm logo após o núcleo, e o painel admin
  e as demais partes novas vêm depois deles, mantendo entre si a ordem que já tinham.
- **A2.** A API pública fica por último e mantém a condição da E4·1 ("só quando precisarem").
- **A3.** As falas já estão em `docs/decisoes/` na branch `docs/produto-modulos` (PR #2). O Documentador só as grava
  nesta branch, na etapa 11, se o PR #2 não tiver entrado antes.
