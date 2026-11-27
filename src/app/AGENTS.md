# AGENTS.md · src/app (telas)

> Rascunho para o dono aprovar (E15). Escrito por: Arquiteto de software · Revisado por: (a preencher) · Norma: modelo C4, Clean Architecture, padrão agents.md, WCAG 2.2.
> Fonte: `AGENTS.md`, `ARCHITECTURE.md`, `DESIGN.md`, `docs/guias/processo-sdd.md`. Este arquivo não cria regra nova.

## O que mora aqui
As telas e os componentes (`ARCHITECTURE.md` §3). Toda ação da tela vai para `src/server`.

## Regras que valem aqui
- Toda tela segue só o `DESIGN.md`; peça, cor, nome ou medida fora dele não se usa: entra lá primeiro, com o dono (`DESIGN.md`, cabeçalho e §10 item 8).
- Uma só ação preta por tela; nomes dos botões pela tabela (`DESIGN.md` §1, §5 e §6).
- Toda tela tem os estados vazio, sem resultado, carregando, erro e sucesso (`DESIGN.md` §8).
- Acessibilidade WCAG 2.2 AA: contraste, toque 44/40, foco visível, nada só por cor (`ARCHITECTURE.md` §11; `DESIGN.md` §9).
- Lugar de módulo e seção vem do mapa único da navegação (`DESIGN.md` §7). Listas longas paginadas (`ARCHITECTURE.md` §11).
- Revisor de design confere pelo checklist antes do dono ver (`DESIGN.md` §10).

## Nunca aqui
- Falar com o banco, nem com a trava; ter regra de negócio (`ARCHITECTURE.md` §3 e §4).
- Dado pessoal ou de saúde no endereço (URL) ou em notificação; segredo no código (`ARCHITECTURE.md` §7; `SECURITY.md` §2; `DESIGN.md` §8b).

## Prova exigida
Tela: teste de ponta a ponta nas larguras do `DESIGN.md` e conferência do dono na prévia (`AGENTS.md` §9). Larguras ainda não definidas (`docs/guias/processo-sdd.md` §6).
