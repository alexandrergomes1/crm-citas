# Guia · Idiomas

Pouco está decidido sobre idiomas. Este guia traz só o que já existe escrito; o resto é lacuna registrada.

## Vale hoje

- **Desenvolvimento em português; lançamento em português, espanhol e inglês.** A tradução é item da lista da virada (`docs/runbooks/go-live.md`), não do trabalho de agora. Decisão do dono de 20/11/2026: `docs/adr/2026-11-20-idiomas.md`.
- **Texto de cada tela num lugar só do arquivo** (um objeto de textos no topo), nunca espalhado pelo JSX: é o que permite traduzir depois (`docs/guias/telas.md` §3).
- **Nenhuma estrutura de idioma** (biblioteca, arquivos de tradução, tabelas de tradução) sem spec própria aprovada.
- **Dinheiro e data** saem pelas funções únicas de formato do estúdio: moeda e fuso são do estúdio.
- **Gatilho para reabrir:** o dono pedir a tradução antes da virada, ou a virada ser marcada.

## Escrito no arquivo do módulo, ainda a confirmar

`docs/produto/modulos/idi-idiomas.md` guarda o plano antigo (três camadas de idioma: interface, conteúdo do estúdio e comunicação com a cliente; moeda e fuso do estúdio, não do idioma; textos em EN e ES 15 a 30 % maiores, com conferência em 390 px também nesses idiomas; termos legais da ficha com tradução revisada). Tudo lá está **a confirmar** até a ficha curta do módulo; não vale como regra antes disso.

## Lacuna registrada

- **Biblioteca de idiomas:** Paraglide está previsto na stack e não instalado (`docs/reference/stack.md`); o plano antigo citava next-intl. Sem decisão.
- **Variantes:** nada escrito sobre pt-BR × pt-PT nem sobre es-ES. `docs/projeto/produto.md` diz "pt, es, en"; o arquivo do módulo cita `pt-BR`. Os países do lançamento são Espanha, Brasil e Portugal.
- **Onde moram os textos, datas e moedas por idioma:** sem decisão.
- **Gênero dos rótulos** (feminino por padrão) em es e en: sem guia.
- **DDI padrão do telefone:** sem decisão.
- **Teste de idioma** (chaves faltando, layout com texto maior): não existe.

## Origem

`docs/adr/2026-11-20-idiomas.md` · `docs/produto/modulos/idi-idiomas.md` (regras de negócio e pendências) · `.claude/skills/ui-standards/SKILL.md` §4 e "Proibido" · `docs/reference/stack.md` · `docs/projeto/produto.md` · `docs/ICEBOX.md` item 21 · `docs/runbooks/go-live.md` linha 12.
