# ADR 0021 · Agenda: a profissional vê só a própria coluna (substitui uma linha do ADR 0020)

- **Status:** Proposto, até a revisão de outro papel (E16·1) · decisão técnica que aplica respostas do dono
  (`AGENTS.md` §5) · 28/11/2026, com a spec `specs/20261128-020000-agenda/spec.md` (§3, RF-10, CA-13; §16 e §17)
- **Autor:** Arquiteto de software · **Norma:** modelo C4 e ADR; OWASP ASVS 4.0.3 V4.1.3 (menor privilégio), V4.1.5
  (falha fechada), V4.2.1 (dado de outra pessoa); RGPD art. 5(1)(c) (minimização)
- **Revisão (E16·1):** pendente · Engenheiro de segurança e Auditor de risco (acesso) · Revisor de código (matriz)
- **Substitui:** a linha 45 do `docs/adr/0020-permissao-por-chave-modulo-acao.md`, na tabela "Matriz padrão inicial":
  `| agenda.ver | todos | próprios (as outras colunas só "ocupado") | E26·1·B |`. O resto do ADR 0020 continua valendo.
  O ADR 0020 não é editado: ele diz "para desfazer qualquer linha: ADR novo que a substitui".
- **Aviso ao dono:** em uma linha, no pedido de revisão do plano (`AGENTS.md` §3 regra 3).

## Contexto
A linha do ADR 0020 vinha da E26·1·B: a profissional via a própria coluna e as das colegas só como "ocupado". Em
28/11/2026 o dono deu duas respostas que a trocam (gravadas na spec, link
https://claude.ai/code/session_018cV8b958nnbLyXPMKPeaNK):
- **Ordem de 28/11** (spec §16, literal): "E cada profissional só vê o dela e não dos demais. Salvo se tiver no perfil
  liberar pra ver ou ver ocupação (exibe marcado mas info bloqueada/ocupado como o exemplo que deu)."
- **E58·A** (spec §17): o padrão é só a própria coluna; "ver as outras" e "ver ocupação" entram com a tela de perfis
  (item 6a da fila); **sem "Ocupado" nesta spec**.

## Decisão

| Chave | Recepção | Profissional | Resposta |
|---|---|---|---|
| `agenda.ver` | todos | **próprios: só a própria coluna; as outras não aparecem nem saem do servidor, nem como "ocupado"** | ordem do dono de 28/11 e E58·A (no lugar da E26·1·B) |

- "Próprios" em `agenda.ver` quer dizer **a própria coluna e nada mais**. Não existe alcance nem chave de ocupação.
- Valem nas duas camadas, como no ADR 0006 · D7: a política de leitura de `public.bloqueios` só entrega a linha a quem
  tem `todos`, ou `proprios` e a linha é da própria pessoa; com `proprios`, o servidor só pede e só devolve a coluna da
  pessoa (CA-13).
- As outras linhas da Agenda no ADR 0020 (`agenda.criar`, `.editar`, `.remover`: recepção `todos`, profissional
  `proprios`, E26·2·A) não mudam.
- "Ver as outras" e "ver ocupação" voltam só no item 6a, com ADR próprio (chave ou alcance novo, ADR 0020 · D2 e D10).

## Motivo e norma
- É a resposta do dono sobre acesso (`AGENTS.md` §5: acesso é decisão dele); o ADR só a registra na matriz.
- Menor privilégio (ASVS V4.1.3) e minimização (RGPD art. 5(1)(c)): a profissional não precisa saber quando as colegas
  estão ocupadas para fazer o próprio trabalho na v1.
- Tirar o "ocupado" tira uma leitura privilegiada (função `security definer` de "ocupados") e uma ida ao banco por tela
  (ADR 0006 · D3 e D7).

## Consequências
- `src/domain/acesso/matriz.ts` ganha a linha `agenda.ver` com `proprios` para a profissional, citando esta resposta
  (`plan.md` §2.1); a cópia no banco (migration M2) e o teste de divergência (ADR 0020 · D8) ficam iguais a ela.
- A tela da profissional tem uma coluna só e não mostra o botão "Equipe N de M" (spec Assumption 6, a confirmar no
  pedido de merge). Isso é regra de tela, não de acesso.
- As specs do Agendamento, que repetem "E26·1·B" para `agendamento.ver`, devem conferir com o dono se a mesma ordem
  vale lá; este ADR **não** muda a linha `agendamento.*` do ADR 0020.
- Para desfazer: ADR novo que substitui este, com o motivo.

## Não verificado
- Nenhum código, migration ou teste foi escrito ou rodado por este ADR.
- Se a ordem de 28/11 vale também para `agendamento.ver` não foi perguntado ao dono (fica com a spec do Agendamento).
