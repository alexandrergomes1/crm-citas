# Guia · Desempenho

Hoje a única regra medida é o **número de idas ao banco**. Tempo de tela ainda não tem limite nem medição.

## Vale hoje: orçamento de idas ao banco

Limites, proibições e como se mede: `docs/guias/servidor.md` §Orçamento de idas ao banco (números completos em `docs/reference/db-budget.md`).

## Vale hoje: na tela

- O estado "carregando" só aparece depois de 0,3 s (`DESIGN.md` §8).
- Na revisão da tela, a lista de desempenho fica "não verificado: sem rotina de medição" até existir rotina sem IA (`docs/guias/telas.md` §4).

## Lacuna registrada

- **Medição por tela:** não existe rotina nem limite. O "3 segundos no celular" que constava não tem prova; o limite é decisão técnica, proposta com a medição na mão (`docs/ICEBOX.md` item 35).
- **Limites do Cloudflare Workers** (tempo de CPU, subrequisições) e tempo limite da API do banco: não medidos (`docs/ICEBOX.md` item 30).
- Metas antigas (ex.: comanda p95 < 1,5 s) são do sistema antigo e não valem.

## Origem

`docs/reference/db-budget.md` · `docs/reference/server.md` · `.claude/skills/ui-standards/SKILL.md` §4 · `.claude/agents/ui-qa.md` lista 3 · `docs/reorganizacao/design-system-aprovado/design-6a-edicao.md` §8 · `docs/ICEBOX.md` itens 30 e 35 · `docs/produto/modulos/plt-plataforma.md` (PLT-55) e `com-comanda.md` (COM-35, antigo).
