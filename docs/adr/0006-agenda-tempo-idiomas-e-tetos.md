# ADR 0006 · Agenda: idiomas sem biblioteca, dia do estúdio por Intl, tetos e "Desfazer" por recriação

- **Status:** Proposto · decisões técnicas (`AGENTS.md` §5) · 28/11/2026. Vale quando a spec
  `specs/20261128-020000-agenda/spec.md` for aprovada pelo dono.
- **Autor:** Arquiteto de software · **Norma:** modelo C4 e ADR; Clean Architecture; Twelve-Factor; WCAG 2.2;
  `ARCHITECTURE.md` §5 e §11 · **Revisão:** pendente (Revisor de código; D3 também Engenheiro de dados)
- **Aviso ao dono:** em uma linha, junto do pedido de aprovação da spec (`AGENTS.md` §3 regra 3).
- **Detalhe:** `specs/20261128-020000-agenda/plan.md` §5 e §6. Decisões de banco (tabelas do antigo): ADR 0007, do
  Engenheiro de dados.

## Contexto
A Agenda é a primeira tela com texto em três idiomas (RNF-05), a primeira regra que depende do fuso do estúdio (RN-01,
RN-02, dias de 23 h e 25 h) e o primeiro módulo que lê o banco por tela (RNF-02, RN-08). O `AGENTS.md` §3 regra 6 manda
reusar antes de criar.

## Decisões

| # | Decisão | Motivo e norma |
|---|---|---|
| D1 | Idiomas por arquivos próprios (`src/app/i18n/pt.ts`, `es.ts`, `en.ts`), com as chaves do `pt.ts` como tipo das outras duas; troca de marcadores e plural por `Intl.PluralRules`; data e hora por `Intl.DateTimeFormat`. Sem biblioteca de idiomas | o `Intl` é nativo no Node e no navegador (reuso, `AGENTS.md` §3 regra 6); o tipo faz a checagem acusar chave faltando, e um teste acusa texto vazio ou marcador diferente; três idiomas fixos não pedem carga dinâmica. Biblioteca entra num ADR novo se vier formato de mensagem complexo |
| D2 | Limites do dia do estúdio calculados em `src/domain` só com `Intl.DateTimeFormat` (deslocamento do fuso no instante), sem `Temporal` e sem biblioteca de datas; o dia começa no primeiro instante que tem aquela data no fuso | o Node 26 tem `Temporal`, mas não foi verificado no Cloudflare Workers (`ARCHITECTURE.md` §12) nem no Chromium do teste; o `Intl` existe nos três. Regra pura com teste (`ARCHITECTURE.md` §3 e §11), cobrindo 23 h, 25 h e a meia-noite que não existe |
| D3 | Tetos: leitura do dia com no máximo **3 idas ao banco** (estúdio, colunas, bloqueios; 4 quando o Agendamento entrar) e **500 itens** por dia, consultados com `limit 501` para saber se passou | `ARCHITECTURE.md` §5 e §11 (limite de idas por tela; nada cortado calado, RN-08). 500 cobre 20 colunas com um item por hora em 24 h; abaixo do `max_rows` 1000 da API local (`supabase/config.jsonc`). Provado por teste do servidor que conta as idas |
| D4 | "Desfazer" depois de excluir bloqueio = criar de novo com os mesmos dados, pelas mesmas portas e com a mesma regra de conflito; nada fica guardado no banco depois de excluído | minimização (RGPD art. 5(1)(c)): sem lixeira nem coluna de excluído; o registro (porta 6) mostra a exclusão e a nova criação. Custo: o bloqueio volta com outro `id` e pode dar conflito se o horário foi ocupado |
| D5 | A escolha do "Equipe N de M" fica no armazenamento local do navegador, por estúdio, só com identificadores das colunas escondidas | spec Assumption 2; sem dado pessoal (`ARCHITECTURE.md` §7); não precisa de tabela nem de ida ao banco |
| D6 | As dúvidas E26 viram uma constante em `src/domain/agenda/acesso.ts` e uma versão das políticas do banco; nenhuma chave de liga e desliga para as outras opções | menor código e menor superfície de ataque (OWASP ASVS V1.4, V4.1); a troca de resposta é decisão do dono, que reabre a spec |

## Consequências
- Texto novo de qualquer módulo entra nos três arquivos; a checagem de tipos falha se faltar um.
- A base de `src/app/i18n/` neste formato nasce na `feat/entrar-servico` (antes do núcleo); cada módulo, a Agenda
  inclusive, só acrescenta o próprio bloco nos três arquivos.
- Outros módulos que precisem do dia do estúdio usam `src/domain/agenda/dia.ts`; se ele virar geral, muda de pasta
  num ADR novo.
- A spec do Agendamento sobe o teto de idas para 4 no ADR dela.
- Para desfazer qualquer linha: ADR novo que a substitui, com o motivo.
